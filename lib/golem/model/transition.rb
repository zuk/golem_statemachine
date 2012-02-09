# To change this template, choose Tools | Templates
# and open the template in the editor.

module Golem
  module Model
    class Transition
      attr_reader :from
      attr_reader :to
      attr_accessor :guards
      attr_accessor :callbacks
      
      attr_accessor :comment

      def initialize(from, to, guards = [], callbacks = {})
        @from = from
        @to = to
        
        raise ArgumentError, "'guards' must be an Enumerable collection of Golem::Model::Conditions but is #{guards.inspect}" unless
          guards.blank? || (guards.kind_of?(Enumerable) && guards.all?{|g| g.kind_of?(Golem::Model::Condition)})

        @guards = guards
        
        raise ArgumentError, "'callbacks' must be a Hash of Golem::Model::Callbacks but is #{callbacks.inspect}" unless
          callbacks.blank? || (callbacks.kind_of?(Hash) && callbacks.all?{|k, c| c.kind_of?(Golem::Model::Callback)})

        # only the :on_transition callback is currently implemented, but using a Hash of callbacks here leaves open
        # the possibility of other callbacks (e.g. :on_start, :on_finish, etc.)
        @callbacks = callbacks
      end

      def to_s
        s ="Transition from #{from} to #{to}"
        s << " [#{guards.collect{|g| g.to_s}.join(" and ")}]" unless guards.empty?
        s << " / #{callbacks.collect{|k,v| v.to_s}.join(",")}" unless callbacks.blank? || callbacks.values.all?{|v| v.blank?}
        return s
      end
    end
  end
end
