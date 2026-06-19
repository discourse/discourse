# frozen_string_literal: true

module NodeExecutionHelpers
  def execute_node_output(
    configuration:,
    item: nil,
    input_items: nil,
    input_groups: nil,
    node_context: nil,
    user: nil,
    &block
  )
    item = { "json" => {} } if item.nil? && input_items.nil?
    input_items = input_items || [item]
    node_credentials = configuration.fetch("credentials") { {} }
    node_parameters = configuration.except("credentials")
    action = described_class.new(parameters: node_parameters, credentials: node_credentials)
    resolver_context = { "$json" => input_items.first&.dig("json") || {} }
    sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context, user: user)
    resolver =
      DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox, user: user)
    kwargs = {
      input_items: input_items,
      input_groups: input_groups,
      resolver: resolver,
      parameters: node_parameters,
      credentials: node_credentials,
      property_schema: described_class.property_schema,
      credential_schema: described_class.credentials,
      node_identifier: described_class.identifier,
      resolver_context: resolver_context,
      user: user,
    }
    kwargs[:node_context] = node_context if node_context

    ctx = DiscourseWorkflows::Executor::NodeExecutionContext.new(**kwargs)
    output_arrays = action.execute(ctx)
    DiscourseWorkflows::ItemContract.validate_output_arrays!(
      output_arrays,
      source: described_class.name,
      ports: described_class.ports(node_parameters),
    )
    block&.call(ctx)
    output_arrays
  ensure
    resolver&.dispose
    sandbox&.dispose
  end

  def execute_node(configuration:, item: { "json" => {} })
    result = execute_node_output(configuration: configuration, item: item)
    result.first.first["json"]
  end
end

RSpec.configure { |config| config.include NodeExecutionHelpers }
