# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Execute do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:user)
    fab!(:workflow, :discourse_workflows_workflow) do
      Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
    end
    fab!(:trigger_node, :discourse_workflows_node) do
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:manual",
        name: "Manual Trigger",
        position_index: 0,
      )
    end

    let(:params) { { trigger_node_id: trigger_node.id } }

    before do
      SiteSetting.discourse_workflows_enabled = true
      DiscourseWorkflows::Registry.reset!
      DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Manual::V1)
    end

    after { DiscourseWorkflows::Registry.reset! }

    context "when trigger node does not exist" do
      let(:params) { { trigger_node_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:trigger_node) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates an execution record" do
        expect { result }.to change { DiscourseWorkflows::Execution.count }.by(1)
      end
    end
  end
end
