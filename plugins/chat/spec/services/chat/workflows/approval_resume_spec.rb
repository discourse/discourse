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

    let(:resume_token) { execution.resume_token }
    let(:params) { { execution_id:, approved: true, action_token:, channel_id: channel.id } }
    let(:execution_id) { execution.id }
    let(:action_token) { "#{resume_token}:approve" }

    before { SiteSetting.chat_enabled = true }

    context "when plugin is disabled" do
      let(:execution_id) { 1 }
      let(:action_token) { "abc:approve" }

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
      let(:action_token) { "abc:approve" }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when execution is not waiting" do
      fab!(:execution) { Fabricate(:discourse_workflows_execution, status: :success) }
      let(:action_token) { "abc:approve" }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when action_token does not match" do
      fab!(:execution) do
        Fabricate(:discourse_workflows_execution, status: :waiting, resume_token: "correct-token")
      end
      let(:action_token) { "wrong-token:approve" }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when action_type is missing" do
      fab!(:execution) do
        Fabricate(:discourse_workflows_execution, status: :waiting, resume_token: "correct-token")
      end
      let(:action_token) { "correct-token" }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when action_type is unrecognized" do
      fab!(:execution) do
        Fabricate(:discourse_workflows_execution, status: :waiting, resume_token: "correct-token")
      end
      let(:action_token) { "correct-token:unknown" }

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
        let(:action_token) { "#{resume_token}:deny" }
        let(:params) { { execution_id:, approved: false, action_token:, channel_id: channel.id } }

        it { is_expected.to run_successfully }

        it "resumes the execution as denied" do
          result
          expect(execution.reload.status).to eq("success")
        end
      end
    end
  end
end
