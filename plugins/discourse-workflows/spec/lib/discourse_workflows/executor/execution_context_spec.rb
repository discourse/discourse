# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::ExecutionContext do
  fab!(:workflow, :discourse_workflows_workflow)

  let(:trigger_data) { { "topic_id" => 1 } }
  let(:execution_context) do
    described_class.new(workflow: workflow, trigger_data: trigger_data, user: nil)
  end

  describe "#store_context" do
    it "stores values by key" do
      execution_context.store_context("my_node", [{ "json" => { "x" => 1 } }])

      expect(execution_context.context["my_node"]).to eq([{ "json" => { "x" => 1 } }])
    end

    it "warns when storing a reserved key" do
      allow(Rails.logger).to receive(:warn)

      execution_context.store_context("trigger", [{ "json" => {} }])

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

      expect(context["__execution"]).to include("id", "workflow_id", "workflow_name", "resume_url")
      expect(context["__execution"]["workflow_id"]).to eq(workflow.id)
      expect(context["__execution"]["resume_url"]).to match(
        %r{/workflows/webhooks/\d+\?token=[a-f0-9-]+},
      )
    end

    it "appends webhook suffix to resume_url when present" do
      context = execution_context.resolver_context("__webhook_suffix" => "my-hook/path")
      expect(context["__execution"]["resume_url"]).to match(
        %r{/workflows/webhooks/\d+/my-hook/path\?token=},
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

      expect(execution_context.context).to include("trigger" => trigger_data, "node_a" => "data_a")
      expect(
        execution_context.node_context_for(OpenStruct.new(id: "node_a", name: "node_a")),
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
  end
end
