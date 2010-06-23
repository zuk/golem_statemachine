require 'golem/model/state'
require 'golem/model/event'
require 'golem/model/transition'
require 'golem/model/callback'
require 'golem/model/condition'

require 'golem/dsl/event_def'

module Golem
  module DSL
    class StateDef
      def initialize(machine, state_name, options = {}, &block)
        @machine = machine
        @state = @machine.get_or_define_state(state_name)
        @options = options
        instance_eval(&block) if block
      end

      def on(event_name, options = {}, &block)
        Golem::DSL::EventDef.new(@machine, @state, event_name, options, &block)
      end

      def enter(callback = nil, &block)
        raise Golem::DefinitionSyntaxError, "Provide either a callback method or a block, not both." if callback && block
        @state.callbacks[:on_enter] = Golem::Model::Callback.new(block || callback)
      end

      def exit(callback = nil, &block)
        raise Golem::DefinitionSyntaxError, "Provide either a callback method or a block, not both." if callback && block
        @state.callbacks[:on_exit] = Golem::Model::Callback.new(block || callback)
      end
    end
  end
end
