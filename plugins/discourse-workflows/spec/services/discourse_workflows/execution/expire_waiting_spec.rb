# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::ExpireWaiting do
  describe ".call" do
    subject(:result) { described_class.call }

    fab!(:user)
    fab!(:channel, :chat_channel)

    before do
      SiteSetting.discourse_workflows_enabled = true
      SiteSetting.chat_enabled = true
    end

    def create_waiting_execution(timeout_minutes:, timeout_action:)
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:manual",
              "type_version" => "1.0",
              "name" => "Manual",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "wait-1",
              "type" => "action:chat_approval",
              "type_version" => "1.0",
              "name" => "Wait",
              "position" => {
                "x" => 200,
                "y" => 0,
              },
              "position_index" => 1,
              "configuration" => {
                "message" => "Approve?",
                "channel_id" => channel.id.to_s,
                "timeout_minutes" => timeout_minutes.to_s,
                "timeout_action" => timeout_action,
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "wait-1",
              "source_output" => "main",
            },
          ],
        )

      DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
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
      it "resumes the expired execution as denied" do
        freeze_time

        execution = create_waiting_execution(timeout_minutes: 30, timeout_action: "deny")
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
      it "delegates expired timer waits to the timer handler" do
        freeze_time

        execution =
          Fabricate(
            :discourse_workflows_execution,
            status: :waiting,
            waiting_until: 1.minute.ago,
            waiting_node_id: "wait-1",
            waiting_config: {
              "wait_type" => "timer",
              "timeout_action" => "deny",
              "timeout_minutes" => "30",
            },
          )

        DiscourseWorkflows::Executor::WaitHandlers::Timer.expects(:on_timeout).with(execution)
        result

        expect(result).to run_successfully
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
