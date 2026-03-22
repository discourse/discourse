# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::ExpireWaiting do
  describe ".call" do
    subject(:result) { described_class.call }

    fab!(:user)
    fab!(:channel, :chat_channel)

    before do
      SiteSetting.discourse_workflows_enabled = true
      SiteSetting.chat_enabled = true
      DiscourseWorkflows::Registry.reset!
      DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Manual)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::WaitForApproval)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::SetFields)
    end

    after { DiscourseWorkflows::Registry.reset! }

    def create_waiting_execution(timeout_minutes:, timeout_action:)
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

      trigger_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:manual",
          name: "Manual",
          position_index: 0,
        )

      wait_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:wait_for_approval",
          name: "Wait",
          position_index: 1,
          configuration: {
            "message" => "Approve?",
            "channel_id" => channel.id.to_s,
            "timeout_minutes" => timeout_minutes.to_s,
            "timeout_action" => timeout_action,
          },
        )

      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: trigger_node,
        target_node: wait_node,
      )

      DiscourseWorkflows::Executor.new(trigger_node, {}).run
    end

    context "when plugin is disabled" do
      before { SiteSetting.discourse_workflows_enabled = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
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
      it "resumes the expired execution as denied" do
        freeze_time

        execution = create_waiting_execution(timeout_minutes: 30, timeout_action: "deny")
        expect(execution.status).to eq("waiting")

        freeze_time(31.minutes.from_now)
        result

        execution.reload
        expect(execution.status).to eq("success")
        expect(execution.context["Wait"].first["json"]["approved"]).to eq(false)
        expect(execution.context["Wait"].first["json"]["timed_out"]).to eq(true)
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

    context "when execution has no timeout" do
      it "does not expire the execution" do
        execution = Fabricate(:discourse_workflows_execution, status: :waiting, waiting_until: nil)

        result
        expect(execution.reload.status).to eq("waiting")
      end
    end
  end
end
