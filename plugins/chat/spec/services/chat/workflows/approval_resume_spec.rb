# frozen_string_literal: true

RSpec.describe Chat::Workflows::ApprovalResume do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:execution_id) }
    it { is_expected.to validate_presence_of(:action_token) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:user)
    fab!(:channel, :chat_channel)

    let(:params) { { execution_id:, approved: true, action_token: } }
    let(:execution_id) { execution.id }
    let(:action_token) { execution.waiting_config&.dig("approve_token") }

    before { SiteSetting.chat_enabled = true }

    context "when plugin is disabled" do
      let(:execution_id) { 1 }
      let(:action_token) { "abc" }

      before { SiteSetting.discourse_workflows_enabled = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "when contract is invalid" do
      let(:execution_id) { nil }
      let(:action_token) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when execution does not exist" do
      let(:execution_id) { -1 }
      let(:action_token) { "abc" }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when execution is not waiting" do
      fab!(:execution) { Fabricate(:discourse_workflows_execution, status: :success) }
      let(:action_token) { "abc" }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when execution is waiting on a different handler type" do
      fab!(:execution) do
        Fabricate(
          :discourse_workflows_execution,
          status: :waiting,
          waiting_config: {
            "wait_type" => "timer",
          },
        )
      end
      let(:action_token) { "abc" }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when action_token does not match" do
      fab!(:execution) do
        Fabricate(
          :discourse_workflows_execution,
          status: :waiting,
          waiting_config: {
            "wait_type" => "chat_approval",
            "approve_token" => "correct_approve_token",
            "deny_token" => "correct_deny_token",
          },
        )
      end
      let(:action_token) { "stale_token" }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when everything is valid" do
      fab!(:workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:manual", name: "Manual"
            g.node "wait-1",
                   "action:chat_approval",
                   name: "Wait",
                   configuration: {
                     "message" => "Approve?",
                     "channel_id" => channel.id.to_s,
                   }
            g.chain "trigger-1", "wait-1"
          end
        Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)
      end

      let(:execution) { DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run }

      it { is_expected.to run_successfully }

      it "resumes the execution" do
        result
        expect(execution.reload.status).to eq("success")
      end

      context "when denied" do
        let(:params) { { execution_id:, approved: false, action_token: } }

        it { is_expected.to run_successfully }

        it "resumes the execution as denied" do
          result
          expect(execution.reload.status).to eq("success")
        end
      end
    end
  end
end
