require 'golem/model/condition'
require 'golem/model/callback'

module Golem
  module DSL
    class TransitionDef
      def initialize(machine, event, from_state, options = {}, &block)
        @machine = machine
        @event = event
        @from = from_state
        
        if options[:to].blank? || options[:to] == :self
          @to = options[:to] = @state
        else
          @to = @machine.get_or_define_state(options[:to])
        end
        
        callbacks = {}
        callbacks[:on_transition] = options[:action] if options[:action]

        @transition = Golem::Model::Transition.new(@from, @to || @from, options[:guards], callbacks)

        if options[:comment]
          @transition.comment = options[:comment]
        end

        instance_eval(&block) if block

        @from.transitions_on_event[@event] ||= []
        @from.transitions_on_event[@event] << @transition
      end

      def guard(callback_or_options = {}, guard_options = {}, &block)
        if callback_or_options.kind_of? Hash
          callback = block
          guard_options = callback_or_options
        else
          callback = callback_or_options
        end
        
        @transition.guards << Golem::Model::Condition.new(callback, guard_options)
      end

      def action(callback = nil, &block)
        #if @transition.callbacks[:on_transition]
        #  puts "WARNING: Overriding event action for #{@transition.to_s.inspect}."
        #end

        callback = block unless callback

        @transition.callbacks[:on_transition] = Golem::Model::Callback.new(callback)
      end
      
      def comment(comment)
        if @transition.comment
          @transition.comment += "\n#{comment}"
        else
          @transition.comment = comment
        end
      end
    end
  end
end
