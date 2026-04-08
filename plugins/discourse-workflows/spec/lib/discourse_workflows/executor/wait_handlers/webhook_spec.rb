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

    it "sets waiting_until and enqueues timeout job when timeout is configured" do
      state = build_state(execution)
      handler = described_class.new(state)
      wait = DiscourseWorkflows::WaitForWebhook.new(timeout_amount: 2, timeout_unit: "hours")

      freeze_time do
        handler.pause!(wait)

        execution.reload
        expect(execution.waiting_until).to eq_time(2.hours.from_now)

        job = Jobs::DiscourseWorkflows::ExpireWebhookWait.jobs.last
        expect(job).to be_present
        expect(job["args"].first["execution_id"]).to eq(execution.id)
      end
    end

    it "leaves waiting_until nil and does not enqueue timeout job when no timeout" do
      state = build_state(execution)
      handler = described_class.new(state)
      wait = DiscourseWorkflows::WaitForWebhook.new

      handler.pause!(wait)

      execution.reload
      expect(execution.waiting_until).to be_nil
      expect(Jobs::DiscourseWorkflows::ExpireWebhookWait.jobs).to be_empty
    end
  end

  describe ".on_timeout" do
    it "resumes with the waiting step input items" do
      execution_data =
        instance_double(
          DiscourseWorkflows::ExecutionData,
          find_step: {
            "input" => [{ "json" => { "url" => "https://example.com" } }],
          },
        )
      timed_out_execution =
        instance_double(
          DiscourseWorkflows::Execution,
          execution_data: execution_data,
          waiting_config: {
          },
          waiting_node_id: "wait-1",
        )

      DiscourseWorkflows::Executor.expects(:resume).with(
        timed_out_execution,
        [{ "json" => { "url" => "https://example.com" } }],
      )

      described_class.on_timeout(timed_out_execution)
    end
  end
end
