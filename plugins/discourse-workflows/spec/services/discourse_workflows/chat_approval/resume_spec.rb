# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ChatApproval::Resume do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:execution_id) }
    it { is_expected.to validate_presence_of(:wait_nonce) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:user)
    fab!(:channel, :chat_channel)

    let(:params) { { execution_id:, approved: true, wait_nonce: } }
    let(:execution_id) { execution.id }
    let(:wait_nonce) { execution.waiting_config&.dig("wait_nonce") }

    before { SiteSetting.chat_enabled = true }

    context "when plugin is disabled" do
      let(:execution_id) { 1 }
      let(:wait_nonce) { "abc" }

      before { SiteSetting.discourse_workflows_enabled = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "when contract is invalid" do
      let(:execution_id) { nil }
      let(:wait_nonce) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when execution does not exist" do
      let(:execution_id) { -1 }
      let(:wait_nonce) { "abc" }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when execution is not waiting" do
      fab!(:execution, :discourse_workflows_execution) do
        Fabricate(:discourse_workflows_execution, status: :success)
      end
      let(:wait_nonce) { "abc" }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when execution is waiting on a different handler type" do
      fab!(:execution, :discourse_workflows_execution) do
        Fabricate(
          :discourse_workflows_execution,
          status: :waiting,
          waiting_config: {
            "wait_type" => "timer",
          },
        )
      end
      let(:wait_nonce) { "abc" }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when wait_nonce does not match" do
      fab!(:execution, :discourse_workflows_execution) do
        Fabricate(
          :discourse_workflows_execution,
          status: :waiting,
          waiting_config: {
            "wait_type" => "chat_approval",
            "wait_nonce" => "correct_nonce",
          },
        )
      end
      let(:wait_nonce) { "stale_nonce" }

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
        let(:params) { { execution_id:, approved: false, wait_nonce: } }

        it { is_expected.to run_successfully }

        it "resumes the execution as denied" do
          result
          expect(execution.reload.status).to eq("success")
        end
      end
    end
  end
end
