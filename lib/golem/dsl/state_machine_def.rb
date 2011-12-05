require 'golem/model/state_machine'
require 'golem/model/state'
require 'golem/model/callback'

require 'golem/dsl/state_def'

module Golem
  module DSL
    class StateMachineDef
      attr_reader :machine_name

      def initialize(klass, machine_name = nil, &block)
        @klass = klass # this is the Class that we to endow with FSM behaviour
        @machine = Golem::Model::StateMachine.new(machine_name)
        instance_eval(&block) if block
      end

      def machine
        @machine
      end

      def state(state_name, options = {}, &block)
        Golem::DSL::StateDef.new(@machine, state_name, options, &block)
      end

      def all_states
        @machine.all_states.collect{|state| StateDef.new(@machine, state.name)}
      end

      def initial_state(state)
        @machine.initial_state = @machine.get_or_define_state(state)
      end

      # Sets or returns the state_attribute name.
      def state_attribute(attribute = nil)
        if attribute.nil?
          @state_attribute
        else
          @state_attribute = attribute
        end
      end

      # Sets the state_attribute name.
      def state_attribute=(attribute)
        @machine.state_attribute = attribute
      end
      
      # Sets the state_attribute reader.
      def state_attribute_reader(reader = nil)
        @machine.state_attribute_reader = reader
      end
      
      # Sets the state_attribute writer.
      def state_attribute_writer(writer = nil)
        @machine.state_attribute_writer = writer
      end

      def on_all_transitions(callback = nil, &block)
        raise Golem::DefinitionSyntaxError, "A callback or block must be given for on_all_transitions" unless
          (callback || block)
        raise Golem::DefinitionSyntaxError, "Either a callback or block, not both, must be given for on_all_transitions" if
          (callback && block)
        callback ||= block
        unless callback.kind_of?(Golem::Model::Callback)
          callback = Golem::Model::Callback.new(callback)
        end
        @machine.on_all_transitions = callback
      end

      def on_all_events(callback = nil, &block)
        raise Golem::DefinitionSyntaxError, "A callback or block must be given for on_all_events" unless
          (callback || block)
        raise Golem::DefinitionSyntaxError, "Either a callback or block, not both, must be given for on_all_events" if
          (callback && block)
        callback ||= block
        unless callback.kind_of?(Golem::Model::Callback)
          callback = Golem::Model::Callback.new(callback)
        end
        @machine.on_all_events = callback
      end
    end
  end
end
