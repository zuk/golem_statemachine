require 'test_helper'
require 'statemachine_assertions'
require File.dirname(__FILE__)+'/../lib/golem'

# Because Monster has two statemachines, 'affect' and 'mouth', this test
# allows for validating statemachine behaviour when there are multiple
# statemachines defined within the same class.
class MonsterTest < Test::Unit::TestCase
  include StatemachineAssertions

  def setup
    @klass = Class.new
    @klass.instance_eval do
      include Golem
    end
  end

  def test_define_statemachine
    @klass.instance_eval do
      define_statemachine do
        initial_state :test
      end
    end

    assert_kind_of Golem::Model::StateMachine, @klass.statemachines[:statemachine]
  end

  def test_define_invalid_statemachine
    assert_raise Golem::DefinitionSyntaxError do
      @klass.instance_eval do
        define_statemachine do
          # no inital_state
        end
      end
    end
  end

  def test_define_multiple_statemachines
    @klass.instance_eval do
      define_statemachine(:alpha) do
        initial_state :test
      end

      define_statemachine(:beta) do
        initial_state :test
      end
    end

    assert_kind_of Golem::Model::StateMachine, @klass.statemachines[:alpha]
    assert_kind_of Golem::Model::StateMachine, @klass.statemachines[:beta]
    assert_not_same @klass.statemachines[:alpha], @klass.statemachines[:beta]

    # check that defining a default statemachine after defining named statemachines is okay
    @klass.instance_eval do
      define_statemachine do
        initial_state :test
      end
    end

    assert_kind_of Golem::Model::StateMachine, @klass.statemachines[:statemachine]
    assert_not_same @klass.statemachines[:alpha], @klass.statemachines[:statemachine]
    assert_not_same @klass.statemachines[:beta], @klass.statemachines[:statemachine]
  end

  def test_define_duplicate_statemachine
    @klass.instance_eval do
      define_statemachine(:alpha) do
        initial_state :test
      end
    end

    assert_raise ArgumentError do
      @klass.instance_eval do
        define_statemachine(:alpha) do
        end
      end
    end
  end

  def test_define_multiple_invalid_statemachines
    assert_raise Golem::DefinitionSyntaxError do
      @klass.instance_eval do
        define_statemachine(:alpha) do
          initial_state :one
        end

        define_statemachine(:beta) do
        end
      end
    end
  end

  def test_define_state_attribute
    @klass.instance_eval do
      define_statemachine do
        initial_state :one
      end

      define_statemachine(:alpha) do
        initial_state :two
      end

      define_statemachine(:beta) do
        state_attribute :foo
        initial_state :three
      end
    end

    obj = @klass.new
    assert_equal :one, obj.state
    assert_equal :two, obj.alpha_state
    assert_equal :three, obj.foo
  end
  
  def test_define_state_attribute_reader_symbol
    @klass.instance_eval do
      define_statemachine do
        initial_state :one
        
        state_attribute_reader :foo
        
        state :worked
      end
      
      define_method(:foo) do
        return :worked
      end
    end

    obj = @klass.new
    assert_equal :worked, obj.state
  end
  
  def test_define_state_attribute_reader_proc
    @klass.instance_eval do
      define_statemachine do
        initial_state :one
        
        state_attribute_reader(Proc.new do |obj|
          obj.foo
        end)
        
        state :worked
      end
      
      define_method(:foo) do
        return :worked
      end
    end

    obj = @klass.new
    assert_equal :worked, obj.state
  end
  
  def test_define_state_attribute_writer_symbol
    @klass.instance_eval do
      define_statemachine do
        initial_state :one
        
        state_attribute_writer :foo=
        state_attribute_reader :foo
        
        state :worked
      end
      
      define_method(:foo=) do |new_state|
        @foo = new_state
      end
      define_method(:foo) do
        @foo
      end
    end

    obj = @klass.new
    assert_equal :one, obj.state
    
    obj.state = :worked
    assert_equal :worked, obj.state
    assert_equal :worked, obj.instance_variable_get(:@foo)
  end
  
  def test_define_state_attribute_writer_proc
    @klass.instance_eval do
      define_statemachine do
        initial_state :one
        
        state_attribute_writer(Proc.new do |obj, new_state|
          obj.foo = new_state
        end)
        state_attribute_reader :foo
        
        state :worked
      end
      
      define_method(:foo=) do |new_state|
        @foo = new_state
      end
      define_method(:foo) do
        @foo
      end
    end

    obj = @klass.new
    assert_equal :one, obj.state
    
    obj.state = :worked
    assert_equal :worked, obj.state
    assert_equal :worked, obj.instance_variable_get(:@foo)
  end


  def test_define_states
    @klass.instance_eval do
      define_statemachine do
        initial_state :one
        state :one
        state :two
      end

      define_statemachine(:alpha) do
        initial_state :one
        state :one
        state :two
      end

      define_statemachine(:beta) do
        initial_state :three
        state :one
        state :two
        state :three
      end
    end

    assert_equal :one, @klass.statemachines[:statemachine].states[:one].name
    assert_equal 2, ([:one, :two] & @klass.statemachines[:statemachine].states.collect{|s| s.name}).size
    assert_equal 2, ([:one, :two] & @klass.statemachines[:alpha].states.collect{|s| s.name}).size
    assert_equal 3, ([:one, :two, :three] & @klass.statemachines[:beta].states.collect{|s| s.name}).size
    assert_not_same @klass.statemachines[:statemachine].states[:one], @klass.statemachines[:statemachine].states[:two]
    assert_not_same @klass.statemachines[:alpha].states[:one], @klass.statemachines[:beta].states[:one]
  end

  def test_define_events
    @klass.instance_eval do
      define_statemachine(:alpha) do
        initial_state :one
        state :one do
          on :go, :to => :two
        end
        state :two do
          on :go do
            transition :to => :three
          end
        end
        state :three, :to => :one do
          on :go, :to => :one do
            transition
          end
        end
      end

      define_statemachine(:beta) do
        initial_state :b
        state :a do
          on :doit, :to => :b
          on :foo, :action => Proc.new{|arg| puts arg}
        end
        state :b do
          on :doit do
            transition :to => :a
          end
        end
      end
    end

    assert_equal [:go], @klass.statemachines[:alpha].events.collect{|e| e.name}
    ev = @klass.statemachines[:alpha].events[:go]
    assert_equal :go, ev.name

    assert_equal_arrays [:doit, :foo], @klass.statemachines[:beta].events.collect{|e| e.name}
  end


  def test_define_transitions_in_event_to
    sm = sm_def_helper do
      state :a do
        on :go, :to => :b
      end
      state :b do
        on :go, :to => :a do
          transition # inherits on :to
          transition :to => :b # overrides on :to
        end
      end
    end

    assert_transition_on_event sm, :go, :a, :b
    assert_transition_on_event sm, :go, :b, :a
    assert_transition_on_event sm, :go, :b, :b
    assert_no_transition_on_event sm, :go, :a, :a
  end

  
  def test_define_self_transitions
    sm = sm_def_helper do
      state :a do
        on :go
      end
      state :b do
        on :go do
          transition :to => :self
        end
      end
    end

    assert_transition_on_event sm, :go, :a, :a
    assert_transition_on_event sm, :go, :b, :b
    assert_no_transition_on_event sm, :go, :a, :b
    assert_no_transition_on_event sm, :go, :b, :a
  end


  def test_define_state_actions
    enter_b_proc = Proc.new{puts "hi!"}

    sm = sm_def_helper do
      state :a do
        enter :hi
        exit :bye
      end
      state :b do
        enter enter_b_proc
        exit do
          puts "bye!"
        end
      end
    end

    assert_equal :hi, sm.states[:a].callbacks[:on_enter].callback
    assert_equal :bye, sm.states[:a].callbacks[:on_exit].callback
    assert_equal enter_b_proc, sm.states[:b].callbacks[:on_enter].callback
    assert_equal Proc, sm.states[:b].callbacks[:on_exit].callback.class
  end


  def test_define_transition_guards
    sm = sm_def_helper do
      state :a do
        on :go_1 do
          transition :to => :self do
            guard :ready?
            guard :steady?
          end
        end
        on :go_2 do
          transition :to => :self, :if => :ready?
        end
        on :go_3 do
          transition :to => :self, :if => :ready? do
            guard :steady?
          end
        end
        on :go_4, :if => :ready?
        on :go_5, :if => :ready? do
          transition :to => :b, :if => :steady? do
            guard :maybe?
          end
          transition :to => :c, :if => :maybe?
          transition :to => :self
        end
      end
    end

    assert_transition_on_event_has_guard sm, :go_1, :a, :a, :ready?
    assert_transition_on_event_has_guard sm, :go_1, :a, :a, :steady?

    assert_transition_on_event_has_guard sm, :go_2, :a, :a, :ready?

    assert_transition_on_event_has_guard sm, :go_3, :a, :a, :ready?
    assert_transition_on_event_has_guard sm, :go_3, :a, :a, :steady?

    assert_transition_on_event_has_guard sm, :go_4, :a, :a, :ready?

    assert_transition_on_event_has_guard sm, :go_5, :a, :b, :ready?
    assert_transition_on_event_has_guard sm, :go_5, :a, :b, :steady?
    assert_transition_on_event_has_guard sm, :go_5, :a, :b, :maybe?

    assert_transition_on_event_has_guard sm, :go_5, :a, :c, :ready?
    assert_transition_on_event_has_guard sm, :go_5, :a, :c, :maybe?
    assert_transition_on_event_does_not_have_guard sm, :go_5, :a, :c, :steady?

    assert_transition_on_event_has_guard sm, :go_5, :a, :a, :ready?
    assert_transition_on_event_does_not_have_guard sm, :go_5, :a, :a, :maybe?
    assert_transition_on_event_does_not_have_guard sm, :go_5, :a, :a, :steady?
  end

  def test_define_transition_guards_failure_messages
    sm = sm_def_helper do
      state :a do
        on :move, :if => :movable?, :guard_options => {:failure_message => "it's not movable"} do
          transition :to => :b do
            guard :not_stuck?, :failure_message => "it's stuck"
            guard :not_busy?, :failure_message => "it's busy"
          end
          transition :to => :c do
            guard :not_tired?, :failure_message => "it's tired"
          end
          transition :to => :self, :if => :not_busy?
        end
        on :spin do
          transition :to => :self do
            guard :not_tired?, :failure_message => "it's tired"
            guard :not_busy?, :failure_message => "it's busy"
          end
        end
      end
    end

    @klass.instance_eval do
      attr_accessor :tired
      attr_accessor :stuck
      attr_accessor :movable
      attr_accessor :busy

      define_method(:movable?) do
        @movable
      end

      define_method(:not_busy?) do
        !@busy
      end

      define_method(:not_tired?) do
        !@tired
      end

      define_method(:not_stuck?) do
        !@stuck
      end
    end

    assert_transition_on_event_has_guard sm, :move, :a, :b, :movable?
    assert_transition_on_event_has_guard sm, :move, :a, :b, :not_stuck?
    assert_transition_on_event_has_guard sm, :move, :a, :b, :not_busy?
    assert_transition_on_event_does_not_have_guard sm, :move, :a, :b, :not_tired?

    assert_transition_on_event_has_guard sm, :move, :a, :c, :movable?
    assert_transition_on_event_does_not_have_guard sm, :move, :a, :c, :not_stuck?
    assert_transition_on_event_does_not_have_guard sm, :move, :a, :c, :not_busy?
    assert_transition_on_event_has_guard sm, :move, :a, :c, :not_tired?

    assert_transition_on_event_has_guard sm, :move, :a, :a, :movable?
    assert_transition_on_event_does_not_have_guard sm, :move, :a, :a, :not_stuck?
    assert_transition_on_event_does_not_have_guard sm, :move, :a, :a, :not_tired?
    assert_transition_on_event_has_guard sm, :move, :a, :a, :not_busy?

    assert_transition_on_event_does_not_have_guard sm, :spin, :a, :a, :movable?
    assert_transition_on_event_has_guard sm, :spin, :a, :a, :not_busy?
    assert_transition_on_event_has_guard sm, :spin, :a, :a, :not_tired?
    assert_transition_on_event_does_not_have_guard sm, :spin, :a, :a, :not_stuck?

    obj = @klass.new
    obj.movable = false

    raised = false
    begin
      obj.move!
    rescue Golem::ImpossibleEvent => e
      assert_match(/because it's not movable/, e.message)
      raised = true
    ensure
      # be careful -- we end up here if assert_match fails!
      assert raised
    end
    
    obj.stuck = true

    raised = false
    begin
      obj.move!
    rescue Golem::ImpossibleEvent => e
      assert_match(/because it's not movable/, e.message)
      raised = true
    ensure
      # be careful -- we end up here if assert_match fails!
      assert raised
    end

    obj.tired = true
    obj.movable = true

    assert_nothing_raised do
      obj.move! # follows only available transition --> to self
    end
    assert_equal :a, obj.state

    
    obj.busy = true
    obj.tired = false

    # make sure second the guard (is_busy?) works
    raised = false
    begin
      obj.spin!
    rescue Golem::ImpossibleEvent => e
      assert_match(/because it's busy/, e.message)
      raised = true
    ensure
      # be careful -- we end up here if assert_match fails!
      assert raised
    end
  end

  private

  def sm_def_helper(&block)
    @klass.instance_eval do
      define_statemachine do
        initial_state :a
        instance_eval(&block) if block_given?
      end
    end
    return @klass.statemachines[:statemachine]
  end
end

