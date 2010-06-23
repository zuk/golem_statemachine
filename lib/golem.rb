require 'rubygems'
require 'activesupport'

require 'golem/dsl/state_machine_def'
require 'ruby-debug'
module Golem
  def self.included(mod)
    mod.extend Golem::ClassMethods
  end

  module ClassMethods
    def define_statemachine(statemachine_name = nil, options = {}, &block)
      default_statemachine_name = :statemachine
      
      class_inheritable_hash(:statemachines) unless respond_to?(:statemachines)
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
        case
        when state_attribute.respond_to?(:call)
          state = state_attribute.call(self)
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
        
        case
        when state_attribute.respond_to?(:call)
          state_attribute.call(self, new_state)
        when Object.const_defined?('ActiveRecord') && self.kind_of?(ActiveRecord::Base)
          self[state_attribute.to_s] = new_state.to_s # store as String rather than Symbol to prevent serialization weirdness
        else
          self.instance_variable_set("@#{state_attribute}", new_state)
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
          
          # for every event defined in each statemachine we define
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
                  raise Golem::ImpossibleEvent, impossible.values.collect{|e| e.message}.uniq.join("\n")
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
  end

  class DefinitionSyntaxError < StandardError
  end

  class InvalidStateError < StandardError
  end
  
end
