module Golem
  module Model
    class Condition < Golem::Model::Callback
      attr_accessor :failure_message

      def initialize(callback, options = {})
        @callback = callback
        @failure_message = options[:failure_message]
      end
    end
  end
end
