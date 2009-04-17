require 'golem/model/state'
require 'golem/model/event'
require 'golem/model/transition'
require 'golem/model/callback'

module Golem
  module DSL
    class StateDef
      def initialize(machine, state)
        @machine = machine
        if state.is_a?(Golem::Model::State)
          @state = state
        else
          @state = @machine.states[state] ||= Golem::Model::State.new(state)
        end
      end

      def on(event_name, options = {}, &decision)
        event = @machine.events[event_name] ||= Golem::Model::Event.new(event_name)

        if decision
          dd = DecisionDef.new(@machine, @state, event)
          dd.instance_eval(&decision)
        else
          if options[:to]
            to = @machine.states[options[:to]] ||= Golem::Model::State.new(options[:to])
          else
            to = @state
          end

          if options[:guard] || options[:if]
             options[:guard] = Golem::Model::Callback.new(options[:guard] || options[:if]) # :guard and :if mean the same thing
          end

          if options[:action]
             options[:action] = Golem::Model::Callback.new(options[:action]) # :guard and :if mean the same thing
          end

          @state.transitions_on_event[event.name] ||= []
          @state.transitions_on_event[event.name] << Golem::Model::Transition.new(@state, to, options)
        end
      end

      def enter(callback = nil, &block)
        raise "Provide either a callback method or a block, not both." if callback && block
        @state.callbacks[:enter] = Golem::Model::Callback.new(block || callback)
      end

      def exit(callback = nil, &block)
        raise "Provide either a callback method or a block, not both." if callback && block
        @state.callbacks[:exit] = Golem::Model::Callback.new(block || callback)
      end
    end
  end
end
