# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WebhookTestListener::Cancel do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:listener_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:other_admin, :admin)
    fab!(:workflow) do
      graph = build_workflow_graph { |g| g.node "webhook-1", "trigger:webhook" }
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: false, **graph)
    end

    let(:trigger_node) { workflow.find_node("webhook-1") }
    let(:listener) do
      DiscourseWorkflows::WebhookTestListener.create!(
        workflow: workflow,
        user: admin,
        trigger_node: trigger_node,
      )
    end
    let(:params) { { workflow_id: workflow.id, listener_id: listener.listener_id } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { workflow_id: workflow.id, listener_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when workflow does not exist" do
      let(:params) { { workflow_id: -1, listener_id: listener.listener_id } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when listener does not exist" do
      let(:params) { { workflow_id: workflow.id, listener_id: SecureRandom.uuid } }

      it { is_expected.to fail_to_find_a_model(:listener) }
    end

    context "when listener belongs to another workflow" do
      fab!(:other_workflow) do
        graph = build_workflow_graph { |g| g.node "webhook-2", "trigger:webhook" }
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: false, **graph)
      end

      let(:params) { { workflow_id: other_workflow.id, listener_id: listener.listener_id } }

      it { is_expected.to fail_a_policy(:listener_belongs_to_workflow) }
    end

    context "when listener belongs to another admin" do
      let(:dependencies) { { guardian: other_admin.guardian } }

      it { is_expected.to fail_a_policy(:owns_webhook_test_listener) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "cancels the listener" do
        result

        expect(DiscourseWorkflows::WebhookTestListener.find(listener.listener_id)).to be_nil
      end
    end
  end
end
