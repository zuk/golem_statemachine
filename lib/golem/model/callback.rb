module Golem
  module Model
    class Callback
      attr_accessor :callback

      def initialize(callback, options = {})
        @callback = callback
      end

      def call(obj, *args)
        case @callback
        when Proc
          if @callback.arity.abs > 1
            @callback.call(obj, *args)
          else
            @callback.call(obj)
          end
        else
          if obj.method(@callback).arity.abs > 0
            obj.send(@callback, *args)
          else
            obj.send(@callback)
          end
        end
      end

      def to_s
        "#{@callback.inspect}"
      end
    end
  end
end
