require 'golem/model/event'
require 'golem/model/state'
require 'golem/model/transition'
require 'golem/util/element_collection'

module Golem

  module Model

    class StateMachine
      attr_accessor :name
      attr_accessor :state_attribute
      attr_accessor :state_attribute_reader
      attr_accessor :state_attribute_writer
      attr_reader :states
      attr_reader :events
      attr_accessor :transition_errors

      # Callback executed on every successful transition.
      attr_accessor :on_all_transitions

      # Callback executed on every successful event.
      attr_accessor :on_all_events

      def initialize(name)
        @name = name
        @states = Golem::Util::ElementCollection.new(Golem::Model::State)
        @events = Golem::Util::ElementCollection.new(Golem::Model::Event)
        @transition_errors = []
        @throw_exceptions = false
        @is_transitioning = false
      end

      def initial_state
        @initial_state
      end

      def initial_state=(state)
        # for the sake of readability in debugging, we store initial state by name rather than by reference to a State object
        @initial_state = state.name
      end

      def all_states
        @states
      end

      def all_events
        @events
      end
      
      # true if this statemachine is currently in the middle of a transition
      def is_transitioning?
        @is_transitioning
      end

      def get_current_state_of(obj)
        obj.send(state_attribute)
      end

      def set_current_state_of(obj, state)
        obj.send("#{state_attribute}=".to_sym, state)
      end

      def init(obj)
        # set the initial state
        set_current_state_of(obj, get_current_state_of(obj) || initial_state)
      end

      def fire_event_with_exceptions(obj, event, *args)
        @throw_exceptions = true
        fire_event(obj, event, *args)
      end

      def fire_event_without_exceptions(obj, event, *args)
        @throw_exceptions = false
        fire_event(obj, event, *args)
      end

      def fire_event(obj, event, *args)
        @transition_errors = []
        transition = determine_transition_on_event(obj, event, *args)
        
        on_all_events.call(obj, event, args) if on_all_events

        if transition
          @is_transitioning = true
          
          before_state = states[get_current_state_of(obj)]
          before_state.callbacks[:on_exit].call(obj, *args) if before_state.callbacks[:on_exit]
        
          set_current_state_of(obj, transition.to.name)
          transition.callbacks[:on_transition].call(obj, *args) if transition.callbacks[:on_transition]
          on_all_transitions.call(obj, event, transition, *args) if on_all_transitions

          after_state = states[get_current_state_of(obj)]
          after_state.callbacks[:on_enter].call(obj, *args) if after_state.callbacks[:on_enter]
          
          @is_transitioning = false
          
          save_result = true
          if obj.respond_to?(:save!)
            if @throw_exceptions
              save_result = obj.save!
            else
              (save_result = obj.save!) rescue return false
            end
          elsif obj.respond_to?(:save)
            if @throw_exceptions
              save_result = obj.save
            else
              (save_result = obj.save) rescue return false
            end
          end
          
          return save_result
        else
          return false
        end
      end

      def determine_transition_on_event(obj, event, *args)
        event = @events[event] unless event.is_a?(Golem::Model::Event)

        from_state = states[get_current_state_of(obj)]
        possible_transitions = from_state.transitions_on_event[event.name]

        selected_transition = determine_transition(possible_transitions, obj, *args)

        if selected_transition.nil?
          if @cannot_transition_because.blank?
            msg = "#{event.name.to_s.inspect} is not a valid action for #{obj} because no outgoing transitions are available when #{name.blank? ? "the state" : "#{name} "} is #{from_state}."
            msg << "\n\tPossible transitions are: \n\t\t#{possible_transitions.collect.collect{|t| t.to_s}.join("\n\t\t")}" unless possible_transitions.blank?
          elsif @cannot_transition_because.length == 1
            msg = "#{event.name.to_s.inspect} is not a valid action for #{obj} because #{@cannot_transition_because.first}."
          else
            msg = "#{event.name.to_s.inspect} is not a valid action for #{obj} because #{@cannot_transition_because.uniq.join(" and ")}"
          end

          if @throw_exceptions
            raise Golem::ImpossibleEvent.new(msg, event, obj, @cannot_transition_because)
          else
            obj.transition_errors << msg
          end
        end

        return selected_transition
      end

      def get_or_define_state(state)
        if states[state]
          return states[state]
        else
          case state
          when Golem::Model::State
            return states[state] = state
          when String, Symbol
            return states[state] = Golem::Model::State.new(state)
          else
            raise ArgumentError, "State must be a Golem::Model::State, String, or Symbol but is a #{state.class}"
          end
        end
      end

      def get_or_define_event(event)
        if events[event]
          return events[event]
        else
          case event
          when Golem::Model::Event
            return events[event] = event
          when String, Symbol
            return events[event] = Golem::Model::Event.new(event)
          else
            raise ArgumentError, "Event must be a Golem::Model::Event, String, or Symbol but is a #{event.class}"
          end
        end
      end

#      def get_or_create_state(name, options = {})
#        @states[name] || define_state(name, options)
#      end
#
#      def define_state(name, options = {})
#
#        s.set_callback(:on_enter, options[:enter]) if options[:enter]
#        s.set_callback(:on_exit, options[:exit]) if options[:exit]
#        # TODO: implement :do callback as an "Activity" (Thread/subrocess?)
#        states[name] = s
#        return s
#      end
#
#      def get_or_define_event(name, options = {})
#        @events[name] || define_event(name, options)
#      end
#
#      def define_event(name, options = {}, &block)
#        e = Event.new(name)
#        e.instance_eval(&block) if block
#
#        model.class_eval do
#          define_method("#{name}!") do |*args|
#            model.transaction do
#              e.fire(args)
#            end
#          end
#        end
#
#        @events << e
#        return e
#      end

      private
      
      def determine_transition(possible_transitions, obj, *args)
        return nil if possible_transitions.blank?

        @cannot_transition_because = []
        
        possible_transitions.each do |transition|
          guard_failed = false
          unless transition.guards.empty?
            transition.guards.each do |guard| # all guards must evaluate to true
              unless guard.call(obj, *args)
                @cannot_transition_because << (guard.failure_message || "#{guard} is false")
                guard_failed = true
                break
              end
            end
          end

          next if guard_failed

          return transition
        end

        return nil
      end
      
    end
  end
end
