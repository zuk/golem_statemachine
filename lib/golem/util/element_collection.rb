module Golem
  module Util
    class ElementCollection
      include Enumerable

      def initialize(restricted_to_type = nil)
        @collection = {}
        @restricted_to_type = restricted_to_type
      end

      def [](key)
        return nil if key.nil?
        key = key.name if key.respond_to?(:name)
        @collection[key.to_sym]
      end

      def []=(key, value)
        key = key.name if key.respond_to?(:name)
        raise ArgumentError, "Value must be a #{@restricted_to_type.name.inspect} but is a #{value.class.name.inspect}!" if
          @restricted_to_type && !value.kind_of?(@restricted_to_type)
        @collection[key.to_sym] = value
      end

      def each
        @collection.values.each{|v| yield v}
      end

      def values
        @collection.values
      end
    end
  end
end