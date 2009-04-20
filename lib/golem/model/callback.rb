# To change this template, choose Tools | Templates
# and open the template in the editor.

module Golem
  module Model
    class Callback
      def initialize(callback)
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
        when Array
          @callback.each do |c|
            self.class.new(c).call(*args)
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
