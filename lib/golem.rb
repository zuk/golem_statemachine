require 'active_support/all'
require 'golem/dsl/state_machine_def'

module Golem

  def self.included(mod)
    mod.extend Golem::ClassMethods

    # Override the initialize method in the object we're imbuing with statemachine
    # functionality so that we can do statemachine initialization when the object
    # is instantiated.
    #
    # For ActiveRecord, we use the after_initialize callback instead.
    # FIXME: should use an ActiveRecord::Observer here since this will conflict with
    #        any user-set after_initialize callback.
    mod.class_eval do
      if Object.const_defined?('ActiveRecord') && mod < ActiveRecord::Base
        
        after_initialize do
          if respond_to?(:statemachines)
            self.statemachines.each{|name, sm| sm.init(self)}
          end
        end
        
      else
        
        alias_method :_initialize, :initialize

        def initialize(*args)
          # call the original initialize
          _initialize(*args)

          if respond_to?(:statemachines)
            self.statemachines.each{|name, sm| sm.init(self)}
          end
        end
        
      end
    end
  end
  
  module ClassMethods
    def define_statemachine(statemachine_name = nil, options = {}, &block)
      default_statemachine_name = :statemachine
      
      class_attribute :statemachines unless respond_to?(:statemachines)
      self.statemachines ||= {}
      
      if statemachines.has_key?(statemachine_name || default_statemachine_name)
        if statemachine_name == default_statemachine_name
          raise ArgumentError, "If you are declaring more than one statemachine within the same class, you must give each statemachine a unique name (i.e. define_statemachine(name) do ... end)."
        else
          raise ArgumentError, "Cannot declare a statemachine under #{(statemachine_name || default_statemachine_name).inspect} because this statemachine name is already taken."
        end
      end

      statemachine_def = Golem::DSL::StateMachineDef.new(self, statemachine_name, &block)
      
      statemachine = statemachine_def.machine

      raise Golem::DefinitionSyntaxError, "No initial_state defined for statemachine #{statemachine}!" if statemachine.initial_state.blank?

      self.statemachines[statemachine_name || default_statemachine_name] = statemachine
      class_eval do
        define_method(statemachine_name || default_statemachine_name) do
          statemachines[statemachine_name || default_statemachine_name]
        end
      end

      state_attribute = statemachine_def.state_attribute

      if state_attribute.blank?
        if statemachine_name.nil?
          state_attribute = :state
        else
          state_attribute = "#{statemachine_name}_state".to_sym
        end
      end

      statemachine.state_attribute = state_attribute

      # state reader
      define_method("#{state_attribute}".to_sym) do
        # TODO: the second two cases here should be collapsed into the first
        case
        when statemachine.state_attribute_reader
          if statemachine.state_attribute_reader.respond_to?(:call)
            state = statemachine.state_attribute_reader.call(self)
          else
            state = self.send(statemachine.state_attribute_reader)
          end
        when Object.const_defined?('ActiveRecord') && self.kind_of?(ActiveRecord::Base)
          state = self[state_attribute.to_s] && self[state_attribute.to_s].to_sym
        else
          state = self.instance_variable_get("@#{state_attribute}")
        end
        
        state ||= statemachine.initial_state
        state   = state.to_sym if state.is_a?(String)

        raise InvalidStateError, "#{self} is in an unrecognized state (#{state.inspect})" unless statemachine.states[state]

        state   = statemachine.states[state].name
        
        return state
      end

      # state writer
      define_method("#{state_attribute}=".to_sym) do |new_state|
        new_state = new_state.name if new_state.respond_to?(:name)
        new_state = new_state.to_sym
        raise ArgumentError, "#{new_state.inspect} is not a valid state for #{statemachine}!" unless statemachine.states[new_state]
        
        # transition takes care of calling on_exit, so don't do it if we're in the middle of a transition
        unless statemachine.is_transitioning?
          from_state_obj = statemachine.states[self.send("#{state_attribute}")]
          from_state_obj.callbacks[:on_exit].call(self) if from_state_obj.callbacks[:on_exit]
        end
        
        # TODO: the second two cases here whould be collapsed into the first
        case
        when statemachine.state_attribute_writer
          if statemachine.state_attribute_writer.respond_to?(:call)
            statemachine.state_attribute_writer.call(self, new_state)
          else
            self.send(statemachine.state_attribute_writer, new_state)
          end
        when Object.const_defined?('ActiveRecord') && self.kind_of?(ActiveRecord::Base)
          self[state_attribute.to_s] = new_state.to_s # store as String rather than Symbol to prevent serialization weirdness
        else
          self.instance_variable_set("@#{state_attribute}", new_state)
        end
        
        # transition takes care of calling on_entry, so don't do it if we're in the middle of a transition
        unless statemachine.is_transitioning?
          new_state_obj = statemachine.states[new_state]
          new_state_obj.callbacks[:on_enter].call(self) if new_state_obj.callbacks[:on_enter]
        end
      end

      validate :check_for_transition_errors if respond_to? :validate

      define_method(:transition_errors) do
        @transition_errors ||= []
      end

      define_method(:check_for_transition_errors) do
        if transition_errors && !transition_errors.empty?
          transition_errors.each do |err|
            errors.add_to_base(err)
          end
        end
      end


      statemachine.events.each do |event|
        self.class_eval do
          
          # For every event defined in each statemachine we define a regular
          # (non-exception-raising) method and bang! (exception-raising).
          # This allows for triggering the event by calling the appropriate
          # event-named method on the object.
          [event.name,"#{event.name}!"].each do |meth|
            define_method(meth) do |*args|
              fire_proc = lambda do
                impossible = {}
                results = self.statemachines.collect do |name, sm|
                  begin
                    if meth =~ /!$/
                      sm.fire_event_with_exceptions(self, event, *args)
                    else
                      sm.fire_event_without_exceptions(self, event, *args)
                    end
                  rescue Golem::ImpossibleEvent => e
                    impossible[sm] = e
                  end
                end
                if impossible.size == self.statemachines.size
                  # all statemachines raised Golem::ImpossibleEvent
                  message = impossible.values.collect{|e| e.message}.uniq.join("\n")
                  events = impossible.values.collect{|e| e.event}.uniq
                  events = events[0] if events.size <= 1
                  objects = impossible.values.collect{|e| e.object}.uniq
                  objects = objects[0] if objects.size <= 1
                  reasons = impossible.values.collect{|e| e.reasons}.flatten.uniq
                  reasons = reasons[0] if reasons.size <= 1
                  raise Golem::ImpossibleEvent.new(message, events, objects, reasons)
                end
                results.all?{|result| result == true}
              end

              if self.class.respond_to?(:transaction)
                 # Wrap event call inside a transaction, if supported (i.e. for ActiveRecord)
                self.class.transaction(&fire_proc)
              else
                fire_proc.call
              end
            end
          end

          define_method("determine_#{"#{statemachine_name}_" if statemachine_name}state_after_#{event.name}") do |*args|
            transition = nil
            if self.class.respond_to?(:transaction)
              self.class.transaction do
                # TODO: maybe better to use fire_event + transaction rollback to simulate event firing?
                transition = statemachine.determine_transition_on_event(self, event, *args)
              end
            else
              transition = statemachine.determine_transition_on_event(self, event, *args)
            end

            transition ? transition.to.name : nil
          end
        end
      end
    end
  end

  class ImpossibleEvent < StandardError
    attr_reader :event, :object, :reasons
    def initialize(message, event = nil, object = nil, reasons = nil)
      @event = event
      @object = object
      @reasons = reasons
      super(message)
    end

    def human_explanation
      event = [@event] unless @event.is_a?(Array)
      object = [@object] unless @object.is_a?(Array)
      "'#{event.collect{|ev|ev.name.to_s.humanize.upcase}.join("/")}' for #{object.collect{|ob|ob.to_s}.join("/")} failed"
    end

    def human_reasons
      reasons = [@reasons] unless @reasons.is_a?(Array)
      reasons
    end
  end

  class DefinitionSyntaxError < StandardError
  end

  class InvalidStateError < StandardError
  end
  
end
