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
        "called_by",
        "resume_url",
        "resumeFormUrl",
      )
    end

    it "marks resume_url as conditionally visible" do
      field = described_class.environment_symbols.dig("$execution", :fields, "resume_url")
      expect(field[:display_options]).to eq(
        show: {
          node_present: [{ type: "flow:wait", parameters: { resume: "webhook" } }],
        },
      )
    end

    it "marks resumeFormUrl as conditionally visible" do
      field = described_class.environment_symbols.dig("$execution", :fields, "resumeFormUrl")
      expect(field[:display_options]).to eq(
        show: {
          node_present: [{ type: "action:form", parameters: { page_type: "page" } }],
        },
      )
    end

    it "marks called_by as conditionally visible for workflow call triggers" do
      field = described_class.environment_symbols.dig("$execution", :fields, "called_by")
      expect(field[:display_options]).to eq(
        show: {
          node_present: [{ type: "trigger:workflow_call" }],
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
      context = { "$trigger" => {} }
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
      context = { "$trigger" => {} }
      sandbox = DiscourseWorkflows::JsSandbox.new(context, user: user)

      schema_fields = described_class.environment_symbols["$current_user"][:fields]
      schema_fields.each_key do |field_name|
        result = sandbox.eval("$current_user.#{field_name}")
        expect(result).not_to be_nil, "expected $current_user.#{field_name} to be defined, got nil"
      end
    ensure
      sandbox&.dispose
    end

    it "ExpressionResolver $() returns node output and context accessors" do
      context = {
        "$trigger" => {
        },
        "$json" => {
        },
        "Test Node" => [{ "json" => { "data" => 1 } }],
        "__node_contexts" => {
          "Test Node" => {
            "approved" => true,
          },
        },
      }

      sandbox = DiscourseWorkflows::JsSandbox.new(context, user: user)
      resolver = DiscourseWorkflows::ExpressionResolver.new(context, user: user, sandbox: sandbox)

      item_json = resolver.resolve("={{ $('Test Node').first().json.data }}")
      expect(item_json).to eq(1)

      node_context = resolver.resolve('={{ $("Test Node").context.approved }}')
      expect(node_context).to eq(true)
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "ExpressionResolver exposes $execution" do
      execution =
        Fabricate(:discourse_workflows_execution, status: :running, started_at: Time.current)

      context =
        DiscourseWorkflows::Executor::ExecutionContext.new(
          workflow: execution.workflow,
          trigger_data: {
          },
          user: user,
          execution: execution,
        )
      context.reset!(resume_token: SecureRandom.uuid)

      resolver_ctx = context.resolver_context.merge("$json" => {})
      sandbox = DiscourseWorkflows::JsSandbox.new(resolver_ctx, user: user)
      resolver =
        DiscourseWorkflows::ExpressionResolver.new(resolver_ctx, user: user, sandbox: sandbox)

      result = resolver.resolve("={{ $execution.workflow_id }}")
      expect(result).to eq(execution.workflow.id)
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "omits $execution.called_by for normal executions" do
      execution =
        Fabricate(:discourse_workflows_execution, status: :running, started_at: Time.current)
      context =
        DiscourseWorkflows::Executor::ExecutionContext.new(
          workflow: execution.workflow,
          trigger_data: {
          },
          user: user,
          execution: execution,
        )

      expect(context.resolver_context["__execution"]).not_to have_key("called_by")
    end

    it "ExpressionResolver exposes current-input helpers" do
      context = {
        "$json" => {
          "name" => "current",
        },
        "__input_item" => {
          "json" => {
            "name" => "current",
          },
        },
        "__input_items" => [
          { "json" => { "name" => "first" } },
          { "json" => { "name" => "last" } },
        ],
        "__input_params" => {
          "mode" => "test",
        },
        "__input_context" => {
          "noItemsLeft" => true,
        },
        "$itemIndex" => 1,
      }
      sandbox = DiscourseWorkflows::JsSandbox.new(context, user: user)
      resolver = DiscourseWorkflows::ExpressionResolver.new(context, user: user, sandbox: sandbox)

      expect(resolver.resolve("={{ $input.first().json.name }}")).to eq("first")
      expect(resolver.resolve("={{ $input.last().json.name }}")).to eq("last")
      expect(resolver.resolve("={{ $input.params.mode }}")).to eq("test")
      expect(resolver.resolve("={{ $input.context.noItemsLeft }}")).to eq(true)
      expect(resolver.resolve("={{ $itemIndex }}")).to eq(1)
    ensure
      resolver&.dispose
      sandbox&.dispose
    end
  end
end
