# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::WaitHandlers::Webhook do
  fab!(:user)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }
  fab!(:execution) do
    Fabricate(
      :discourse_workflows_execution,
      workflow: workflow,
      status: :running,
      started_at: Time.current,
    )
  end
  before { SiteSetting.discourse_workflows_enabled = true }

  def build_state(execution)
    state =
      instance_double(
        DiscourseWorkflows::Executor::ExecutionState,
        execution: execution,
        waiting_step:
          DiscourseWorkflows::Executor::Step.new(
            node_id: "wait-1",
            node_name: "Wait",
            node_type: "core:wait",
            position: 0,
            input: [],
          ),
        waiting_node:
          DiscourseWorkflows::WorkflowSnapshot::SnapshotNode.new(
            id: "wait-1",
            type: "core:wait",
            type_version: "1.0",
            name: "Wait",
            position: {
              "x" => 0,
              "y" => 0,
            },
            configuration: {
            },
          ),
        waiting_config: {
        },
        context: {
          "__resume_token" => "test-token",
        },
      )
    allow(state).to receive(:save!)
    state
  end

  describe "#pause!" do
    it "stores resume_token and http_method in waiting_config" do
      state = build_state(execution)
      handler = described_class.new(state)
      wait = DiscourseWorkflows::WaitForWebhook.new(http_method: "POST")

      handler.pause!(wait)

      execution.reload
      expect(execution.status).to eq("waiting")
      expect(execution.waiting_config).to include(
        "wait_type" => described_class.wait_type,
        "resume_token" => "test-token",
        "http_method" => "POST",
        "response_mode" => "immediately",
        "response_code" => "200",
      )
    end
  end
end
