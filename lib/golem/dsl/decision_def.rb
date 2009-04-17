require 'golem/model/state'
require 'golem/model/transition'

module Golem
  module DSL
    class DecisionDef
      def initialize(machine, state, event)
        @machine = machine
        @state = state
        @event = event
      end

      def transition(options, &block)
        if options[:to]
          to = @machine.states[options[:to]] ||= Golem::Model::State.new(options[:to])
        else
          # self-transition
          to = @state
        end

        if options[:guard] || options[:if]
           options[:guard] = Golem::Model::Callback.new(options[:guard] || options[:if]) # :guard and :if mean the same thing
        end

        if block || options[:action]
           options[:action] = Golem::Model::Callback.new(options[:action] || block)
        end
        
        @state.transitions_on_event[@event.name] ||= []
        @state.transitions_on_event[@event.name] << Golem::Model::Transition.new(@state, to, options)
      end

      def method_missing?
        raise SyntaxError, "Only 'transition' declarations can be placed in a state's decision block."
      end
    end
  end
end
