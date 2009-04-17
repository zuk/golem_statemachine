# To change this template, choose Tools | Templates
# and open the template in the editor.

module Golem
  module Model
    class State
      attr_reader :name
      attr_reader :callbacks
      attr_reader :transitions_on_event

      def initialize(name)
        name = name.to_sym unless name.is_a?(Symbol)
        @name = name
        @transitions_on_event = {}
        @callbacks = {}
      end

      def to_s
        name.to_s
      end

      def to_sym
        name.to_sym
      end
    end
  end
end
