# frozen_string_literal: true

module NodeExecutionHelpers
  def execute_node_result(
    configuration:,
    item: { "json" => {} },
    run_as_user: Discourse.system_user
  )
    action = described_class.new(configuration: configuration)
    input_items = [item]
    resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => item.fetch("json") { {} } })
    kwargs = {
      input_items: input_items,
      resolver: resolver,
      configuration: configuration,
      configuration_schema: described_class.configuration_schema,
    }
    kwargs[:run_as_user] = run_as_user if run_as_user

    result = action.execute(DiscourseWorkflows::NodeExecutionContext.new(**kwargs))
    return result if result.is_a?(DiscourseWorkflows::NodeResult)

    DiscourseWorkflows::NodeResult.from_output_arrays(result, ports: described_class.ports)
  end

  def execute_node(configuration:, item: { "json" => {} }, run_as_user: Discourse.system_user)
    result = execute_node_result(configuration: configuration, item: item, run_as_user: run_as_user)
    result.primary_items(ports: described_class.ports).first["json"]
  end
end

RSpec.configure { |config| config.include NodeExecutionHelpers }
