# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ExpressionContextSchema do
  describe ".to_hash" do
    it "returns a hash with environment, node_reference_shape, and item_prefix" do
      schema = described_class.to_hash
      expect(schema).to have_key(:environment)
      expect(schema).to have_key(:node_reference_shape)
      expect(schema).to have_key(:item_prefix)
    end

    it "declares $site_settings, $vars, $current_user, $execution as environment symbols" do
      symbols = described_class.environment_symbols.keys
      expect(symbols).to contain_exactly("$site_settings", "$vars", "$current_user", "$execution")
    end

    it "declares $current_user fields matching JsSandbox#build_current_user" do
      fields = described_class.environment_symbols["$current_user"][:fields]
      expect(fields.keys).to contain_exactly("id", "username")
    end

    it "declares $execution fields matching ExecutionState#execution_variables" do
      fields = described_class.environment_symbols["$execution"][:fields]
      expect(fields.keys).to contain_exactly(
        "id",
        "workflow_id",
        "workflow_name",
        "resume_webhook_url",
      )
    end

    it "marks resume_webhook_url as conditionally visible" do
      field = described_class.environment_symbols.dig("$execution", :fields, "resume_webhook_url")
      expect(field[:visible_if]).to eq(
        node_present: {
          type: "core:wait",
          configuration: {
            resume: "webhook",
          },
        },
      )
    end

    it "marks $current_user as provided_by_trigger" do
      current_user = described_class.environment_symbols["$current_user"]
      expect(current_user[:provided_by_trigger]).to eq(true)
    end

    it "declares node_reference_shape with item.json and context" do
      shape = described_class.node_reference_shape
      expect(shape).to eq(item: { json: :object }, context: :object)
    end

    it "declares $json as the item prefix" do
      expect(described_class.item_prefix).to eq("$json")
    end
  end

  describe "backend alignment" do
    fab!(:user)

    it "JsSandbox exposes core environment symbols" do
      context = { "trigger" => {} }
      sandbox = DiscourseWorkflows::JsSandbox.new(context, user: user)

      # $execution is injected by ExpressionResolver, not JsSandbox directly
      sandbox_symbols = %w[$site_settings $vars $current_user]
      sandbox_symbols.each do |symbol|
        result = sandbox.eval("typeof #{symbol}")
        expect(result).not_to eq("undefined"),
        "expected #{symbol} to be defined in JsSandbox, got undefined"
      end
    ensure
      sandbox&.dispose
    end

    it "JsSandbox $current_user shape matches schema fields" do
      context = { "trigger" => {} }
      sandbox = DiscourseWorkflows::JsSandbox.new(context, user: user)

      schema_fields = described_class.environment_symbols["$current_user"][:fields]
      schema_fields.each_key do |field_name|
        result = sandbox.eval("$current_user.#{field_name}")
        expect(result).not_to be_nil, "expected $current_user.#{field_name} to be defined, got nil"
      end
    ensure
      sandbox&.dispose
    end

    it "ExpressionResolver $() returns shape matching node_reference_shape" do
      context = {
        "trigger" => {
        },
        "$json" => {
        },
        "Test Node" => [{ "json" => { "data" => 1 } }],
        "_node_contexts" => {
          "Test Node" => {
            "approved" => true,
          },
        },
      }

      resolver = DiscourseWorkflows::ExpressionResolver.new(context, user: user)

      item_json = resolver.resolve("={{ $('Test Node').item.json.data }}")
      expect(item_json).to eq(1)

      node_context = resolver.resolve('={{ $("Test Node").context.approved }}')
      expect(node_context).to eq(true)
    ensure
      resolver&.dispose
    end

    it "ExpressionResolver exposes $execution" do
      execution =
        Fabricate(:discourse_workflows_execution, status: :running, started_at: Time.current)

      state =
        DiscourseWorkflows::Executor::ExecutionState.new(
          workflow: execution.workflow,
          trigger_node_id: "t1",
          trigger_data: {
          },
        )
      state.start!

      resolver_ctx = state.resolver_context
      resolver =
        DiscourseWorkflows::ExpressionResolver.new(resolver_ctx.merge("$json" => {}), user: user)

      result = resolver.resolve("={{ $execution.workflow_id }}")
      expect(result).to eq(execution.workflow.id)
    ensure
      resolver&.dispose
    end
  end
end
