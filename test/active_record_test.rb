require 'test_helper'

require 'rubygems'


begin
  require 'sqlite3'
rescue
  gem 'sqlite3-ruby'
  require 'sqlite3'
end

require 'activerecord'

require 'ruby-debug'

class ActiveRecordTest < Test::Unit::TestCase

  def setup
    eval %{
      class Foo < ActiveRecord::Base
        include Golem
      end
    }

    File.delete('test.db') if File.exists?('test.db')
    
    ActiveRecord::Base.establish_connection(
      :adapter => 'sqlite3',
      :database => 'test.db'
    )

    tmp = $stdout
    $stdout = StringIO.new
    ActiveRecord::Schema.define do
      create_table :foos do |t|
        t.column :state, :string, :null => true
        t.column :alpha_state, :string, :null => true
        t.column :status, :string, :null => true
      end
    end
    $stdout = tmp
  end

  def teardown
    self.class.send(:remove_const, :Foo)
  end

  def test_restore_state
    foo = Foo.create(
      :state => 'b',
      :alpha_state => 'c',
      :status => 'd'
    )

    Foo.instance_eval do
      define_statemachine do
        initial_state :a
        state :a
        state :b
        state :c
        state :d
      end

      define_statemachine(:alpha) do
        initial_state :a
        state :a
        state :b
        state :c
        state :d
      end

      define_statemachine(:beta) do
        state_attribute(:status)
        initial_state :a
        state :a
        state :b
        state :c
        state :d
      end
    end

    foo = Foo.find(foo.id)

    assert_equal :b, foo.state
    assert_equal :c, foo.alpha_state
    assert_equal :d, foo.status

    # check that initial state works too
    foo = Foo.create

    foo = Foo.find(foo.id)

    assert_equal :a, foo.state
    assert_equal :a, foo.alpha_state
    assert_equal :a, foo.status
  end

  def test_save_state
    Foo.instance_eval do
      define_statemachine do
        initial_state :a
        state :a do
          on :go, :to => :b
        end
        state :b
        state :c
        state :d
      end

      define_statemachine(:alpha) do
        initial_state :a
        state :a do
          on :go, :to => :c
        end
        state :b
        state :c
        state :d
      end

      define_statemachine(:beta) do
        state_attribute(:status)
        initial_state :a
        state :a do
          on :go, :to => :d
        end
        state :b
        state :c
        state :d
      end
    end

    foo = Foo.create

    assert_equal :a, foo.state
    assert_equal :a, foo.alpha_state
    assert_equal :a, foo.status

    foo.go
    
    assert_equal :b, foo.state
    assert_equal :c, foo.alpha_state
    assert_equal :d, foo.status

    foo = Foo.find(foo.id)

    assert_equal :b, foo.state
    assert_equal :c, foo.alpha_state
    assert_equal :d, foo.status
  end

  def test_transaction_around_fire_event
    #TODO: check that transaction around fire_event is respected (i.e. changes not persisted when an execption is
    #      raised inside an event firing)
  end
end

