# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Execute do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:trigger_node_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:user)
    fab!(:workflow) do
      graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:manual" }
      Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)
    end

    let(:params) { { workflow_id: workflow.id, trigger_node_id: "trigger-1" } }

    context "when contract is invalid" do
      let(:params) { { workflow_id: workflow.id, trigger_node_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when workflows are not enabled" do
      before { SiteSetting.discourse_workflows_enabled = false }

      it { is_expected.to fail_a_policy(:can_execute) }
    end

    context "when workflow does not exist" do
      let(:params) { { workflow_id: -1, trigger_node_id: "trigger-1" } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when trigger node does not exist" do
      let(:params) { { workflow_id: workflow.id, trigger_node_id: "nonexistent" } }

      it { is_expected.to fail_to_find_a_model(:trigger_node) }
    end

    context "when workflow_id is not provided" do
      let(:params) { { trigger_node_id: "trigger-1" } }

      it { is_expected.to run_successfully }

      it "finds the workflow by scanning trigger nodes" do
        expect { result }.to change { DiscourseWorkflows::Execution.count }.by(1)
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates an execution record" do
        expect { result }.to change { DiscourseWorkflows::Execution.count }.by(1)
      end
    end

    context "when user_id is provided" do
      fab!(:execution_user, :user)
      let(:params) do
        { workflow_id: workflow.id, trigger_node_id: "trigger-1", user_id: execution_user.id }
      end

      it { is_expected.to run_successfully }

      it "fetches the correct user" do
        expect(result[:user]).to eq(execution_user)
      end
    end
  end
end
