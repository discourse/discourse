# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)

  def build_workflow
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:post_created", name: "Post Created"
        g.node "set-1",
               "action:set_fields",
               name: "Set Fields",
               configuration: {
                 "mode" => "raw",
                 "include_other_fields" => true,
                 "json_output" => '{"echoed": true}',
               }
        g.chain "trigger-1", "set-1"
      end
    Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
  end

  let(:workflow) { build_workflow }

  let(:manual_options) do
    DiscourseWorkflows::Executor::ExecutionOptions.new(
      user: user,
      execution_mode: :manual,
      draft_execution: true,
    )
  end

  def trigger_output(execution)
    execution.execution_data.run_data["Post Created"].first["outputs"].first["items"]
  end

  def node_output(execution, node_name)
    runs = execution.execution_data.run_data[node_name]
    runs.first["outputs"].first["items"]
  end

  describe "manual execution with pinned trigger data" do
    before do
      workflow.update_node_pin_data!(
        "Post Created",
        [{ "json" => { "post_id" => 1234, "raw" => "pinned" } }],
      )
    end

    it "emits pinned items as the trigger output" do
      execution = described_class.new(workflow, "trigger-1", {}, manual_options).run

      expect(trigger_output(execution).first["json"]).to include("post_id" => 1234)
    end

    it "marks the trigger run as successful" do
      execution = described_class.new(workflow, "trigger-1", {}, manual_options).run

      expect(execution.status).to eq("success")
    end

    it "still runs downstream nodes against the pinned data" do
      execution = described_class.new(workflow, "trigger-1", {}, manual_options).run

      expect(node_output(execution, "Set Fields").first["json"]).to include(
        "echoed" => true,
        "post_id" => 1234,
      )
    end
  end

  describe "normal execution ignores pin data" do
    before do
      workflow.update_node_pin_data!(
        "Post Created",
        [{ "json" => { "post_id" => 9999, "raw" => "should not be used" } }],
      )
    end

    it "uses the real trigger data, not the pin" do
      execution = described_class.new(workflow, "trigger-1", { "post_id" => 1 }).run

      expect(trigger_output(execution).first["json"]).to include("post_id" => 1)
      expect(trigger_output(execution).first["json"]).not_to include("post_id" => 9999)
    end
  end

  describe "pin data on a downstream node" do
    before do
      workflow.update_node_pin_data!("Set Fields", [{ "json" => { "frozen_output" => true } }])
    end

    it "short-circuits the node's execute and emits the pinned items" do
      execution = described_class.new(workflow, "trigger-1", { "post_id" => 1 }, manual_options).run

      expect(node_output(execution, "Set Fields").first["json"]).to eq("frozen_output" => true)
    end
  end
end
