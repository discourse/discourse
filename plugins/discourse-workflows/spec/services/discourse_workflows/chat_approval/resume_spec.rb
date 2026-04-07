# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ChatApproval::Resume do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:execution_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:user)
    fab!(:channel, :chat_channel)

    let(:params) { { execution_id:, approved: true } }
    let(:execution_id) { execution.id }

    before do
      SiteSetting.discourse_workflows_enabled = true
      SiteSetting.chat_enabled = true
    end

    context "when plugin is disabled" do
      let(:execution_id) { 1 }

      before { SiteSetting.discourse_workflows_enabled = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "when contract is invalid" do
      let(:execution_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when execution does not exist" do
      let(:execution_id) { -1 }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when execution is not waiting" do
      fab!(:execution, :discourse_workflows_execution) do
        Fabricate(:discourse_workflows_execution, status: :success)
      end

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

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when everything is valid" do
      fab!(:workflow) do
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
      end

      let(:execution) { DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run }

      it { is_expected.to run_successfully }

      it "resumes the execution" do
        result
        expect(execution.reload.status).to eq("success")
      end

      context "when denied" do
        let(:params) { { execution_id:, approved: false } }

        it { is_expected.to run_successfully }

        it "resumes the execution as denied" do
          result
          expect(execution.reload.status).to eq("success")
        end
      end
    end
  end
end
