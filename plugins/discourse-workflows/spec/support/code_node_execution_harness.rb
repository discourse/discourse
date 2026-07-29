# frozen_string_literal: true

module DiscourseWorkflows
  class CodeNodeExecutionHarness
    RUN_ONCE_FOR_EACH_ITEM = "runOnceForEachItem"

    def initialize(node_class:, sandbox:)
      @node_class = node_class
      @sandbox = sandbox
    end

    def execute(
      code: nil,
      parameters: nil,
      mode: RUN_ONCE_FOR_EACH_ITEM,
      items: [{ "json" => {} }],
      resolver_context: nil
    )
      parameters ||= { "code" => code, "mode" => mode }
      action = @node_class.new(parameters: parameters)
      action.execute(execution_context(items:, parameters:, resolver_context:)).first
    end

    def execute_and_log(
      code: nil,
      parameters: nil,
      mode: RUN_ONCE_FOR_EACH_ITEM,
      items: [{ "json" => {} }],
      resolver_context: nil
    )
      parameters ||= { "code" => code, "mode" => mode }
      context = execution_context(items:, parameters:, resolver_context:)
      @node_class.new(parameters: parameters).execute(context)
      context.log
    end

    private

    def execution_context(items:, parameters:, resolver_context:)
      resolver_context ||= { "$json" => items.first&.dig("json") || {} }
      resolver = ExpressionResolver.new(resolver_context, sandbox: @sandbox)

      Executor::NodeExecutionContext.new(
        input_items: items,
        parameters: parameters,
        resolver: resolver,
        resolver_context: resolver_context,
      )
    end
  end
end
