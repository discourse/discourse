# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::ExpireWaiting do
  describe ".call" do
    subject(:result) { described_class.call }

    fab!(:user)

    def create_waiting_execution(
      timeout_minutes: nil,
      timeout_action: nil,
      timeout_response_items: nil,
      limit_wait_time: true
    )
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
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
      extras = {}
      extras["timeout_action"] = timeout_action if timeout_action
      extras["timeout_response_items"] = timeout_response_items if timeout_response_items
      execution.update!(waiting_config: execution.waiting_config.merge(extras))
      execution
    end

    context "when plugin is disabled" do
      before { SiteSetting.discourse_workflows_enabled = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "when there are no expired executions" do
      it { is_expected.to run_successfully }
    end

    context "when timeout_action is fail" do
      it "fails the expired execution" do
        freeze_time

        execution = create_waiting_execution(timeout_minutes: 30, timeout_action: "fail")
        expect(execution.status).to eq("waiting")

        freeze_time(31.minutes.from_now)
        result

        execution.reload
        expect(execution.status).to eq("error")
        expect(execution.error).to eq("Approval timed out")
      end
    end

    context "when timeout_action is deny" do
      it "resumes the expired execution with timeout_response_items" do
        freeze_time

        execution =
          create_waiting_execution(
            timeout_minutes: 30,
            timeout_action: "deny",
            timeout_response_items: [{ "json" => { "approved" => false, "timed_out" => true } }],
          )
        expect(execution.status).to eq("waiting")

        freeze_time(31.minutes.from_now)
        result

        execution.reload
        expect(execution.status).to eq("success")
        expect(execution.execution_data.context_data["Wait"].first["json"]["approved"]).to be(false)
        expect(execution.execution_data.context_data["Wait"].first["json"]["timed_out"]).to be(true)
      end
    end

    context "when wait_type is timer" do
      it "handles expired timer waits with the generic timeout logic" do
        freeze_time

        execution =
          Fabricate(
            :discourse_workflows_execution,
            status: :waiting,
            waiting_until: 1.minute.ago,
            waiting_node_id: "wait-1",
            waiting_config: {
              "wait_type" => "timer",
              "timeout_action" => "fail",
            },
          )

        result

        execution.reload
        expect(execution.status).to eq("error")
      end
    end

    context "when execution has not timed out" do
      it "does not expire the execution" do
        freeze_time

        execution = create_waiting_execution(timeout_minutes: 60, timeout_action: "fail")

        freeze_time(30.minutes.from_now)
        result

        expect(execution.reload.status).to eq("waiting")
      end
    end

    context "when execution uses the default wait ceiling" do
      it "expires after the executor timeout" do
        freeze_time

        execution = create_waiting_execution(limit_wait_time: false)

        expect(execution.waiting_until).to eq(
          DiscourseWorkflows::Executor::MAX_WAIT_DURATION_SECONDS.seconds.from_now,
        )

        freeze_time(
          DiscourseWorkflows::Executor::MAX_WAIT_DURATION_SECONDS.seconds.from_now + 1.second,
        )
        result

        expect(execution.reload.status).to eq("success")
      end
    end
  end
end
