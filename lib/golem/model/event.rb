module Golem
  module Model
    class Event
      attr_reader :name
      attr_reader :transitions
      attr_reader :callbacks

      def initialize(name)
        @name = name
        @transitions = []
      end

      def add_transition(from, to, options = {})
        @transitions << Transition.new()
      end
    end
  end
end
