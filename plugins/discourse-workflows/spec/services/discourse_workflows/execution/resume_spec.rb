# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::Resume do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:user)
    fab!(:channel, :chat_channel)

    before do
      SiteSetting.discourse_workflows_enabled = true
      SiteSetting.chat_enabled = true
      DiscourseWorkflows::Registry.reset!
      DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Manual::V1)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::SetFields::V1)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::WaitForApproval::V1)
    end

    after { DiscourseWorkflows::Registry.reset! }

    context "when plugin is disabled" do
      let(:params) { { execution_id: 1, approved: true } }

      before { SiteSetting.discourse_workflows_enabled = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "when execution does not exist" do
      let(:params) { { execution_id: -1, approved: true } }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when execution is not waiting" do
      fab!(:execution, :discourse_workflows_execution) do
        Fabricate(:discourse_workflows_execution, status: :success)
      end

      let(:params) { { execution_id: execution.id, approved: true } }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when everything is valid" do
      fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true) }
      fab!(:trigger_node) do
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:manual",
          name: "Manual",
          position_index: 0,
        )
      end
      fab!(:wait_node) do
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:wait_for_approval",
          name: "Wait",
          position_index: 1,
          configuration: {
            "message" => "Approve?",
            "channel_id" => channel.id.to_s,
          },
        )
      end
      fab!(:connection) do
        Fabricate(
          :discourse_workflows_connection,
          workflow: workflow,
          source_node: trigger_node,
          target_node: wait_node,
        )
      end

      let(:execution) { DiscourseWorkflows::Executor.new(trigger_node, {}).run }
      let(:params) { { execution_id: execution.id, approved: true } }

      it { is_expected.to run_successfully }

      it "resumes the execution" do
        result
        expect(execution.reload.status).to eq("success")
      end
    end
  end
end
