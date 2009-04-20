require 'golem/model/event'
require 'golem/model/state'
require 'golem/model/transition'

module Golem

  module Model

    class StateMachine
      attr_accessor :initial_state
      attr_accessor :states
      attr_accessor :events

      attr_accessor :on_all_transitions
      attr_accessor :on_all_events

      def initialize
        @states = ElementCollection.new(Golem::Model::State)
        @events = ElementCollection.new(Golem::Model::Event)
      end

      def all_states
        @states
      end

      def all_events
        @events
      end

      def fire_event(obj, event, *args)
        transition = determine_transition_on_event(obj, event, *args)
        
        on_all_events.call(obj, event, args) if on_all_events

        if transition
          before_state = states[obj.current_state]
          before_state.callbacks[:exit].call(obj, *args) if before_state.callbacks[:exit]

          obj.current_state = transition.to.name
          transition.callbacks[:action].call(obj, *args) if transition.callbacks[:action]
          on_all_transitions.call(obj, event, transition, args) if on_all_transitions

          after_state = states[obj.current_state]
          after_state.callbacks[:enter].call(obj, *args) if after_state.callbacks[:enter]

          obj.save! if obj.respond_to?(:save!)
        end

        return obj.current_state
      end

      def determine_transition_on_event(obj, event, *args)
        event = @events[event] unless event.is_a?(Golem::Model::Event)

        from_state = states[obj.current_state]
        possible_transitions = from_state.transitions_on_event[event.name]

        selected_transition = determine_transition(possible_transitions, obj, *args)

        if selected_transition.blank?
          raise Golem::ImpossibleEvent, "#{obj} cannot currently accept the event #{event.name.inspect}.\n\tPossible transitions were: \n\t\t#{possible_transitions.collect.collect{|t| t.to_s}.join("\n\t\t")}"
        end

        return selected_transition
      end

      def determine_transition(possible_transitions, obj, *args)
        return nil if possible_transitions.blank?

        possible_transitions.each do |transition|
          if transition.guard
            next unless transition.guard.call(obj, *args)
          end
          
          return transition
        end

        return nil
      end

      def get_or_create_state(name, options = {})
        @states[name] || define_state(name, options)
      end

      def define_state(name, options = {})

        s.set_callback(:entry, options[:entry]) if options[:entry]
        s.set_callback(:exit, options[:exit]) if options[:exit]
        # TODO: implement :do callback as an "Activity" (Thread/subrocess?)
        states[name] = s
        return s
      end

      def get_or_define_event(name, options = {})
        @events[name] || define_event(name, options)
      end

      def define_event(name, options = {}, &block)
        e = Event.new(name)
        e.instance_eval(&block) if block

        model.class_eval do
          define_method("#{name}!") do |*args|
            model.transaction do
              e.fire(args)
            end
          end
        end

        @events << e
        return e
      end

      
      class ElementCollection
        include Enumerable

        def initialize(restricted_to_type = nil)
          @collection = {}
          @restricted_to_type = restricted_to_type
        end

        def [](key)
          key = key.name if key.respond_to?(:name)
          @collection[key.to_sym]
        end

        def []=(key, value)
          key = key.name if key.respond_to?(:name)
          raise ArgumentError, "Value must be a #{@restricted_to_type.name.inspect} but is a #{value.class.name.inspect}!" if
            @restricted_to_type && !value.kind_of?(@restricted_to_type)
          @collection[key.to_sym] = value
        end

        def each
          @collection.values.each{|v| yield v}
        end
      end
      
    end
  end
end
