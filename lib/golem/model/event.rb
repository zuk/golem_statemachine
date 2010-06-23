module Golem
  module Model
    class Event
      attr_reader :name
      attr_reader :callbacks

      def initialize(name)
        @name = name
      end
    end
  end
end
