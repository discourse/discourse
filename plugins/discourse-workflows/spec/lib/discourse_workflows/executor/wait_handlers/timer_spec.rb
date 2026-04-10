# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::WaitHandlers::Timer do
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
    it "enqueues ResumeTimer job with correct duration" do
      state = build_wait_state(execution, node_type: "core:wait")
      handler = described_class.new(state)
      wait =
        DiscourseWorkflows::WaitForTimer.new(
          wait_amount: 2,
          wait_unit: "hours",
          wait_duration_seconds: 2.hours.to_i,
        )

      handler.pause!(wait)

      job = Jobs::DiscourseWorkflows::ResumeTimer.jobs.last
      expect(job).to be_present
      expect(job["args"].first["execution_id"]).to eq(execution.id)
    end

    it "sets waiting_until to duration from now" do
      state = build_wait_state(execution, node_type: "core:wait")
      handler = described_class.new(state)
      wait =
        DiscourseWorkflows::WaitForTimer.new(
          wait_amount: 30,
          wait_unit: "minutes",
          wait_duration_seconds: 30.minutes.to_i,
        )

      freeze_time do
        handler.pause!(wait)

        execution.reload
        expect(execution.status).to eq("waiting")
        expect(execution.waiting_until).to eq_time(30.minutes.from_now)
        expect(execution.waiting_config).to include(
          "wait_type" => described_class.wait_type,
          "wait_amount" => 30,
          "wait_unit" => "minutes",
        )
      end
    end
  end

  describe ".on_timeout" do
    it "resumes with the waiting step input items" do
      execution_data =
        instance_double(
          DiscourseWorkflows::ExecutionData,
          find_step: {
            "input" => [{ "json" => { "foo" => "bar" } }],
          },
        )
      execution =
        instance_double(
          DiscourseWorkflows::Execution,
          execution_data: execution_data,
          waiting_config: {
          },
          waiting_node_id: "wait-1",
        )

      DiscourseWorkflows::Executor.expects(:resume).with(
        execution,
        [{ "json" => { "foo" => "bar" } }],
      )

      described_class.on_timeout(execution)
    end
  end
end
