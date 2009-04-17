require 'golem/model/state_machine'
require 'golem/model/state'
require 'golem/model/callback'

require 'golem/dsl/state_def'

module Golem
  module DSL
    class StateMachineDef
      attr_accessor :current_state_method

      def initialize
        @machine = Golem::Model::StateMachine.new
        @current_state_method ||= :state
      end

      def machine
        @machine
      end

      def state(name, &block)
        s = Golem::DSL::StateDef.new(@machine, name)
        s.instance_eval(&block) if block
      end

      def all_states
        @machine.all_states.collect{|s| StateDef.new(@machine, s)}
      end

      def initial_state(state)
        @machine.initial_state = @machine.states[state] ||= Golem::Model::State.new(state)
      end

      def current_state_from(method_name)
        @current_state_method = method_name
      end

      def on_all_transitions(callback)
        unless callback.kind_of?(Golem::Model::Callback)
          callback = Golem::Model::Callback.new(callback)
        end
        @machine.on_all_transitions = callback
      end

      def on_all_events(callback)
        unless callback.kind_of?(Golem::Model::Callback)
          callback = Golem::Model::Callback.new(callback)
        end
        @machine.on_all_events = callback
      end
    end
  end
end
