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
    end
  end
end
