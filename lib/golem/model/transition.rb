# To change this template, choose Tools | Templates
# and open the template in the editor.

module Golem
  module Model
    class Transition
      attr_reader :from
      attr_reader :to
      attr_reader :guard
      attr_reader :callbacks

      def initialize(from, to, options = {})
        @from = from
        @to = to
        @guard = options[:guard]

        @callbacks = {}
        @callbacks[:action] = options[:action]
      end

      def to_s
        s ="Transition from #{from} to #{to} [#{guard.to_s}]"
        s << " / #{callbacks.collect{|k,v| v.to_s}.join(",")}" unless callbacks.blank? || callbacks.values.all?{|v| v.blank?}
        return s
      end
    end
  end
end
