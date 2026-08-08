# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::ExpireWaiting do
  describe ".call" do
    subject(:result) { described_class.call }

    fab!(:user)

    let(:timeout_minutes) { nil }
    let(:timeout_action) { nil }
    let(:limit_wait_time) { true }
    let(:waiting_execution) do
      configuration = { "resume" => "webhook", "limit_wait_time" => limit_wait_time }
      if limit_wait_time
        configuration["timeout_amount"] = timeout_minutes
        configuration["timeout_unit"] = "minutes"
      end

      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual", name: "Manual"
          g.node "wait-1", "flow:wait", name: "Wait", configuration: configuration
          g.chain "trigger-1", "wait-1"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
      execution.update!(timeout_action:) if timeout_action
      execution
    end

    context "when plugin is disabled" do
      before { SiteSetting.enable_discourse_workflows = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "when there are no expired executions" do
      it { is_expected.to run_successfully }
    end

    context "when timeout_action is fail" do
      let(:timeout_minutes) { 30 }
      let(:timeout_action) { "fail" }

      it "fails the expired execution" do
        freeze_time

        expect(waiting_execution.status).to eq("waiting")

        freeze_time(31.minutes.from_now)
        result

        waiting_execution.reload
        expect(waiting_execution.status).to eq("error")
        expect(waiting_execution.error).to eq("Approval timed out")
      end
    end

    context "when the waiting node is no longer in the workflow" do
      it "still fails the expired execution with the generic timeout logic" do
        freeze_time

        execution =
          Fabricate(
            :discourse_workflows_execution,
            status: :waiting,
            waiting_until: 1.minute.ago,
            waiting_node_id: "wait-1",
            timeout_action: "fail",
          )

        result

        execution.reload
        expect(execution.status).to eq("error")
      end
    end

    context "when execution has not timed out" do
      let(:timeout_minutes) { 60 }
      let(:timeout_action) { "fail" }

      it "does not expire the execution" do
        freeze_time

        waiting_execution

        freeze_time(30.minutes.from_now)
        result

        expect(waiting_execution.reload.status).to eq("waiting")
      end
    end

    context "when execution uses the default wait ceiling" do
      let(:limit_wait_time) { false }

      it "expires after the executor timeout" do
        freeze_time

        expect(waiting_execution.waiting_until).to eq_time(
          DiscourseWorkflows::Executor::MAX_WAIT_DURATION_SECONDS.seconds.from_now,
        )

        freeze_time(
          DiscourseWorkflows::Executor::MAX_WAIT_DURATION_SECONDS.seconds.from_now + 1.second,
        )
        result

        expect(waiting_execution.reload.status).to eq("success")
      end
    end
  end
end
