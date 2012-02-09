require 'golem/dsl/transition_def'

module Golem
  module DSL
    class EventDef
      def initialize(machine, on_state, event_name, options, &block)
        @machine = machine
        @state = on_state
        @event = @machine.get_or_define_event(event_name)

        if options[:to]
          @to = @machine.get_or_define_state(options[:to])
        end

        @guards = []

        guard = options[:if] || options[:guard]
        if guard
          if guard.kind_of?(Golem::Model::Condition)
            @guards << guard
          else
            @guards << Golem::Model::Condition.new(guard, options[:guard_options] || {})
          end
        end

        action = options[:action] || options[:on_transition]
        @action = Golem::Model::Callback.new(action) if action

        
        instance_eval(&block) if block_given?

        if @state.transitions_on_event[@event].blank?
          transition :to => (@to || @state), :guards => @guards, :action => @action
        end
      end

      def transition(options = {}, &block)
        if options[:to] == :self
          to = @state
        elsif options[:to]
          to = @machine.get_or_define_state(options[:to])
        else
          to = @to
        end

        options[:to] = to

        guard = options[:if] || options[:guard]
        if guard
          if guard.kind_of?(Golem::Model::Condition)
            guards = @guards + [guard]
          else
            guards = @guards + [Golem::Model::Condition.new(guard)]
          end
        end

        options[:guards] = guards || @guards.dup
        
        action = options[:action] || options[:on_transition]
        if action
          options[:action] = Golem::Model::Callback.new(action) unless action.kind_of?(Golem::Model::Callback)
        else
          options[:action] = @action
        end

        TransitionDef.new(@machine, @event, @state, options.dup, &block)
      end

      def guard(callback_or_options = {}, guard_options = {}, &block)
        # FIXME: are guard_options ever actually used?
        if callback_or_options.kind_of? Hash
          callback = block
          guard_options = callback_or_options
        else
          callback = callback_or_options
        end

        @guards << Golem::Model::Condition.new(callback, guard_options)
      end

      def action(callback = nil, &block)
        callback = block unless callback

        @action = Golem::Model::Callback.new(callback)
      end

    end
  end
end
