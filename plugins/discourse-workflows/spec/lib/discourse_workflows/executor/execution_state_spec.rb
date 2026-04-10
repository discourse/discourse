# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::ExecutionState do
  fab!(:workflow, :discourse_workflows_workflow)

  let(:trigger_data) { { "topic_id" => 1 } }
  let(:state) do
    described_class.new(workflow: workflow, trigger_node_id: "node_1", trigger_data: trigger_data)
  end

  before { state.start! }

  describe "#next_step_position" do
    it "increments with each call" do
      expect(state.next_step_position).to eq(0)
      expect(state.next_step_position).to eq(1)
      expect(state.next_step_position).to eq(2)
    end
  end

  describe "context storage and retrieval" do
    it "stores and retrieves context by key" do
      state.store_context("my_node", [{ "json" => { "x" => 1 } }])

      context = state.resolver_context
      expect(context["my_node"]).to eq([{ "json" => { "x" => 1 } }])
    end

    it "warns when storing context with a reserved key" do
      allow(Rails.logger).to receive(:warn)
      state.store_context("trigger", [{ "json" => {} }])
      expect(Rails.logger).to have_received(:warn).with(/collides with reserved context key/)
    end

    it "does not warn for non-reserved keys" do
      allow(Rails.logger).to receive(:warn)
      state.store_context("my_custom_node", [{ "json" => {} }])
      expect(Rails.logger).not_to have_received(:warn)
    end

    it "merges extra context into resolver_context" do
      state.store_context("node_a", "data_a")

      context = state.resolver_context("$json" => { "extra" => true })
      expect(context["node_a"]).to eq("data_a")
      expect(context["$json"]).to eq({ "extra" => true })
    end

    it "includes _execution variables in resolver_context" do
      context = state.resolver_context
      expect(context["_execution"]).to include("id", "workflow_id", "workflow_name", "resume_url")
      expect(context["_execution"]["workflow_id"]).to eq(workflow.id)
      expect(context["_execution"]["resume_url"]).to match(%r{/workflows/webhooks/.+:.+})
    end
  end

  describe "wait state tracking" do
    it "tracks waiting node and step via mark_wait" do
      node = OpenStruct.new(id: "1", name: "wait_node")
      step = { "node_id" => "1", "status" => "running" }

      state.mark_wait(node: node, step: step)

      expect(state.waiting_node).to eq(node)
      expect(state.waiting_step).to eq(step)
    end
  end

  describe "#save!" do
    it "persists run_data and context to execution_data" do
      state.store_context("node_a", [{ "json" => { "x" => 1 } }])
      state.record_step("node_a", { "node_id" => "1", "status" => "success" })
      state.save!

      ed = state.execution.execution_data
      expect(ed).to be_present
      parsed = JSON.parse(ed.data)
      expect(parsed["context"]["node_a"]).to eq([{ "json" => { "x" => 1 } }])
      expect(parsed["run_data"]["node_a"]).to be_present
    end

    it "truncates context when data exceeds max size" do
      state.store_context("big_data", "x" * 6.megabytes)
      state.save!(max_size: 5.megabytes)

      ed = state.execution.execution_data
      parsed = JSON.parse(ed.data)
      expect(parsed["context"]["_truncated"]).to be(true)
      expect(parsed["context"]["big_data"]).to be_nil
    end
  end

  describe "#resume!" do
    it "restores state from a waiting execution" do
      state.store_context("node_a", "data_a")
      state.record_step("node_a", { "node_id" => "1", "status" => "waiting" })
      state.save!
      state.execution.update!(
        status: :waiting,
        waiting_node_id: "1",
        waiting_config: {
          "node_contexts" => {
            "node_a" => {
              "counter" => 1,
            },
          },
          "step_position" => 1,
        },
      )

      new_state =
        described_class.new(
          workflow: workflow,
          trigger_node_id: "node_1",
          trigger_data: trigger_data,
        )
      new_state.resume!(state.execution)

      expect(new_state.run_data).to have_key("node_a")
      expect(new_state.context).to include("node_a" => "data_a")
      expect(new_state.node_context_for(OpenStruct.new(name: "node_a"))).to eq({ "counter" => 1 })
      expect(new_state.next_step_position).to eq(1)
    end
  end
end
