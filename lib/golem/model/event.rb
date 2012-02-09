module Golem
  module Model
    class Event
      attr_reader :name
      attr_reader :callbacks
      
      attr_accessor :comment

      def initialize(name)
        @name = name
      end
    end
  end
end
