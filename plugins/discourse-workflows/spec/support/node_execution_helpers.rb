# frozen_string_literal: true

module NodeExecutionHelpers
  def execute_node_result(
    configuration:,
    item: { "json" => {} },
    run_as_user: Discourse.system_user
  )
    action = described_class.new(configuration: configuration)
    input_items = [item]
    resolver_context = { "$json" => item.fetch("json") { {} } }
    sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
    resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
    kwargs = {
      input_items: input_items,
      resolver: resolver,
      configuration: configuration,
      property_schema: described_class.property_schema,
      resolver_context: resolver_context,
    }
    kwargs[:run_as_user] = run_as_user if run_as_user

    result = action.execute(DiscourseWorkflows::Executor::NodeExecutionContext.new(**kwargs))
    return result if result.is_a?(DiscourseWorkflows::Executor::NodeResult)

    DiscourseWorkflows::Executor::NodeResult.from_output_arrays(result, ports: described_class.ports)
  ensure
    resolver&.dispose
    sandbox&.dispose
  end

  def execute_node(configuration:, item: { "json" => {} }, run_as_user: Discourse.system_user)
    result = execute_node_result(configuration: configuration, item: item, run_as_user: run_as_user)
    result.primary_items(ports: described_class.ports).first["json"]
  end
end

RSpec.configure { |config| config.include NodeExecutionHelpers }
