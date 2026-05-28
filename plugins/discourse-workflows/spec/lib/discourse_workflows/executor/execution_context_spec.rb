# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::ExecutionContext do
  fab!(:workflow, :discourse_workflows_workflow)

  let(:trigger_data) { { "topic_id" => 1 } }
  let(:execution_context) do
    described_class.new(workflow: workflow, trigger_data: trigger_data, user: nil)
  end

  describe ".generate_resume_token" do
    it "returns a 256-bit url-safe token" do
      expect(described_class.generate_resume_token).to match(/\A[A-Za-z0-9_-]{43}\z/)
    end

    it "returns a different value on each call" do
      expect(described_class.generate_resume_token).not_to eq(described_class.generate_resume_token)
    end
  end

  describe "#reset!" do
    it "assigns a fresh url-safe resume_token by default" do
      execution_context.reset!

      expect(execution_context.resume_token).to match(/\A[A-Za-z0-9_-]{43}\z/)
    end
  end

  describe "#store_context" do
    it "stores values by key" do
      execution_context.store_context("my_node", [{ "json" => { "x" => 1 } }])

      expect(execution_context.context["my_node"]).to eq([{ "json" => { "x" => 1 } }])
    end

    it "still overwrites and warns when storing a reserved top-level key" do
      allow(Rails.logger).to receive(:warn)
      overridden = [{ "json" => { "overridden" => true } }]

      execution_context.store_context("$trigger", overridden)

      expect(execution_context.context["$trigger"]).to eq(overridden)
      expect(Rails.logger).to have_received(:warn).with(/collides with reserved context key/)
    end

    it "still stores and warns when storing an internal resolver key" do
      allow(Rails.logger).to receive(:warn)
      payload = [{ "json" => { "x" => 1 } }]

      execution_context.store_context("__input_item", payload)

      expect(execution_context.context["__input_item"]).to eq(payload)
      expect(Rails.logger).to have_received(:warn).with(/collides with reserved context key/)
    end
  end

  describe "#resolver_context" do
    before do
      execution = Fabricate(:discourse_workflows_execution, workflow: workflow)
      execution_context.execution = execution
      execution_context.reset!(resume_token: SecureRandom.uuid)
      execution_context.store_context("node_a", "data_a")
    end

    it "includes stored context and merged extra context" do
      context = execution_context.resolver_context("$json" => { "extra" => true })

      expect(context["node_a"]).to eq("data_a")
      expect(context["$json"]).to eq({ "extra" => true })
    end

    it "includes execution variables from the schema" do
      context = execution_context.resolver_context

      expect(context["__execution"]).to include(
        "id",
        "workflow_id",
        "workflow_name",
        "resume_url",
        "resumeFormUrl",
      )
      expect(context["__execution"]["workflow_id"]).to eq(workflow.id)
      expect(context["__execution"]["resume_url"]).to match(
        %r{/workflows/waiting/\d+/webhook\?signature=[a-f0-9-]+},
      )
      expect(context["__execution"]["resumeFormUrl"]).to match(
        %r{/workflows/forms/waiting/\d+\.json\?signature=[a-f0-9-]+},
      )
    end

    it "uses the configured workflow name" do
      execution_context.use_workflow_nodes([], workflow_name: "Snapshot workflow")

      expect(execution_context.resolver_context["__execution"]["workflow_name"]).to eq(
        "Snapshot workflow",
      )
    end

    it "appends webhook suffix to resume_url when present" do
      context = execution_context.resolver_context("__webhook_suffix" => "my-hook/path")
      expect(context["__execution"]["resume_url"]).to match(
        %r{/workflows/waiting/\d+/webhook/my-hook/path\?signature=},
      )
    end
  end

  describe "#restore!" do
    it "restores node contexts and preserves trigger data" do
      execution_context.restore!(
        context: {
          "node_a" => "data_a",
        },
        node_contexts: {
          "node_a" => {
            "counter" => 1,
          },
        },
      )

      expect(execution_context.context).to include("$trigger" => trigger_data, "node_a" => "data_a")
      expect(
        execution_context.node_context_for(Struct.new(:id, :name).new("node_a", "node_a")),
      ).to eq("counter" => 1)
    end

    it "exposes node contexts to expressions by node name" do
      workflow.update!(nodes: [{ "id" => "1", "name" => "Node A" }])

      execution_context.restore!(context: {}, node_contexts: { "1" => { "counter" => 1 } })

      expect(execution_context.resolver_context["__node_contexts"]).to eq(
        "Node A" => {
          "counter" => 1,
        },
      )
    end

    it "uses restored workflow nodes for node context names" do
      workflow.update!(nodes: [{ "id" => "1", "name" => "Renamed draft node" }])
      execution_context.use_workflow_nodes([{ "id" => "1", "name" => "Snapshot node" }])

      execution_context.restore!(context: {}, node_contexts: { "1" => { "counter" => 1 } })

      expect(execution_context.resolver_context["__node_contexts"]).to eq(
        "Snapshot node" => {
          "counter" => 1,
        },
      )
    end
  end
end
