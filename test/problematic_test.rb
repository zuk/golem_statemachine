require 'test_helper'

# Tests specifically designed to address bugs/problems discovered along the way.
class ProblematicTest < Test::Unit::TestCase

  def setup
    @klass = Class.new
    @klass.instance_eval do
      include Golem
    end
  end

  def test_fire_event_for_multiple_statemachines
    
    @klass.instance_eval do
      define_statemachine(:engine) do
        initial_state :stopped
        state :stopped do
          on :start, :to => :idle
        end
        state :idle do
          on :start, :to => :running
        end
      end
      define_statemachine(:fan) do
        initial_state :stopped
        state :stopped do
          on :start, :to => :spinning
        end
      end
    end

    widget = @klass.new
    
    assert_equal :stopped, widget.engine_state
    assert_equal :stopped, widget.fan_state

    widget.start
    
    assert_equal :idle, widget.engine_state
    assert_equal :spinning, widget.fan_state

    assert_nothing_raised do
      # :fan will raise Golem::ImpossibleEvent, but :engine can proceed, so nothing is raised
      widget.start!
    end

    assert_equal :running, widget.engine_state
    assert_equal :spinning, widget.fan_state

    assert !widget.start

    assert_raise(Golem::ImpossibleEvent) do
      # neither :fan nor :engine can proceed
      widget.start!
    end

    assert !widget.start
  end

  def test_fire_entry_action_on_initial_state
    @klass.instance_eval do
      class_eval do
        attr_accessor :off
      end
      
      define_statemachine(:engine) do
        initial_state :stopped
        state :stopped do
          enter do |engine|
            engine.off = true
          end
          on :start, :to => :idle
        end
        state :idle do
          enter do |engine|
            engine.off = false
          end
          on :start, :to => :running
        end
      end
    end

    widget = @klass.new

    assert_equal :stopped, widget.engine_state
    assert_equal true, widget.off

    widget.start!

    assert_equal false, widget.off
  end
end

