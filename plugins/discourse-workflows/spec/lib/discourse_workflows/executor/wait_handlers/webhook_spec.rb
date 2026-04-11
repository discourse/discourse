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

  describe "#pause!" do
    it "stores resume_token and http_method in waiting_config" do
      dependencies =
        build_wait_dependencies(
          execution,
          node_type: "core:wait",
          context: {
            "__resume_token" => "test-token",
          },
        )
      handler = described_class.new(**dependencies)
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

    it "stores webhook_suffix when configured" do
      dependencies =
        build_wait_dependencies(
          execution,
          node_type: "core:wait",
          context: {
            "__resume_token" => "test-token",
          },
        )
      handler = described_class.new(**dependencies)
      wait = DiscourseWorkflows::WaitForWebhook.new(webhook_suffix: "after-approval")

      handler.pause!(wait)

      execution.reload
      expect(execution.waiting_config["webhook_suffix"]).to eq("after-approval")
    end

    it "sets waiting_until and enqueues timeout job when timeout is configured" do
      dependencies =
        build_wait_dependencies(
          execution,
          node_type: "core:wait",
          context: {
            "__resume_token" => "test-token",
          },
        )
      handler = described_class.new(**dependencies)
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
      dependencies =
        build_wait_dependencies(
          execution,
          node_type: "core:wait",
          context: {
            "__resume_token" => "test-token",
          },
        )
      handler = described_class.new(**dependencies)
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
