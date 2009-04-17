require 'rubygems'
require 'activesupport'

require 'golem/dsl/state_machine_def'
require 'golem/dsl/state_def'
require 'golem/dsl/decision_def'

module Golem
  def self.included(mod)
    mod.extend Golem::ClassMethods
  end

  module ClassMethods
    def define_statemachine(statemachine_name = :statemachine, options = {}, &block)
      class_inheritable_accessor statemachine_name
      state_machine_def = Golem::DSL::StateMachineDef.new
      state_machine_def.instance_eval(&block)
      self.send("#{statemachine_name}=", state_machine_def.machine)

      send(statemachine_name).events.each do |event|
        self.class_eval do
          define_method("#{event.name}!") do |*args|
            if self.class.respond_to?(:transaction)
              self.class.transaction do
                self.send(statemachine_name).fire_event(self, event, *args)
              end
            else
              self.send(statemachine_name).fire_event(self, event, *args)
            end
          end

          define_method("determine_state_after_#{event.name}") do |*args|
            transition = nil
            if self.class.respond_to?(:transaction)
              self.class.transaction do
                # TODO: maybe use fire_event + transaction rollback to simulate event firing?
                transition = self.send(statemachine_name).determine_transition_on_event(self, event, *args)
              end
            else
              transition = self.send(statemachine_name).determine_transition_on_event(self, event, *args)
            end

            transition ? transition.to.name : nil
          end
        end
      end

      self.class_eval do
        define_method(:current_state) do
          state = self.send(state_machine_def.current_state_method)
          state = self.current_state = self.send(statemachine_name).initial_state if state.nil?
          state = state.to_sym if state.is_a?(String)
          self.send(statemachine_name).states[state].name
        end

        # FIXME: Defining an after_initialize callback may lead to degraded performance... we need to find a better
        #        way to set the initial state
        if self.superclass.name.to_s == 'ActiveRecord::Base'
          #puts "HAVE ACTIVE RECORD"
          #define_method(:after_initialize) do
          #  self.send("#{state_machine_def.current_state_method}=", state_machine_def.machine.initial_state.name)
          #end

          define_method(:current_state=) do |new_state|
            new_state = new_state.name if new_state.respond_to?(:name)
            # We convert the state Symbol into a String for cleaner storage in the database (otherwise we get a weird
            # weird YAML-serialized symbol value).
            self.send("#{state_machine_def.current_state_method}=", new_state.to_s)
            self.current_state
          end
        else
          #puts "NO ACTIVE RECORD"
          #alias_method :_initialize, :initialize
          #define_method(:initialize) do |*args|
          #  self.send("#{state_machine_def.current_state_method}=", state_machine_def.machine.initial_state.name)
          #  _initialize(*args)
          #end

          define_method(:current_state=) do |new_state|
            new_state = new_state.name if new_state.respond_to?(:name)
            self.send("#{state_machine_def.current_state_method}=", new_state)
            self.current_state
          end
        end
      end
    end
  end

  class ImpossibleEvent < StandardError
  end
  
end
