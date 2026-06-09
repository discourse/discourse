# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::FormTestSession::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:trigger_node_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) do
      graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:form" }
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: false, **graph)
    end

    let(:params) { { workflow_id: workflow.id, trigger_node_id: "trigger-1" } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { workflow_id: workflow.id, trigger_node_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when workflow does not exist" do
      let(:params) { { workflow_id: -1, trigger_node_id: "trigger-1" } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when trigger node does not exist" do
      let(:params) { { workflow_id: workflow.id, trigger_node_id: "missing" } }

      it { is_expected.to fail_to_find_a_model(:trigger_node) }
    end

    context "when the node is not a form trigger" do
      fab!(:workflow) do
        graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:manual" }
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: false, **graph)
      end

      it { is_expected.to fail_a_policy(:form_trigger_node) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "stores a retrievable test session" do
        session = DiscourseWorkflows::FormTestSession.find(result[:token])

        expect(session).to have_attributes(
          workflow_id: workflow.id,
          user_id: admin.id,
          trigger_node_id: "trigger-1",
        )
      end
    end
  end
end
