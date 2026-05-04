# frozen_string_literal: true

module NodeExecutionHelpers
  def execute_node_result(
    configuration:,
    item: nil,
    input_items: nil,
    run_as_user: Discourse.system_user,
    &block
  )
    item = { "json" => {} } if item.nil? && input_items.nil?
    input_items = input_items || [item]
    action = described_class.new(configuration: configuration)
    resolver_context = { "$json" => input_items.first&.dig("json") || {} }
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

    ctx = DiscourseWorkflows::Executor::NodeExecutionContext.new(**kwargs)
    raw = action.execute(ctx)
    block&.call(ctx)
    return raw if raw.is_a?(DiscourseWorkflows::Executor::NodeResult)

    DiscourseWorkflows::Executor::NodeResult.from_output_arrays(raw, ports: described_class.ports)
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
