# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Show do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

    let(:params) { { workflow_id: workflow.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when params are not valid" do
      let(:params) { { workflow_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when workflow does not exist" do
      let(:params) { { workflow_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when everything is valid" do
      it "returns the workflow" do
        expect(result).to run_successfully
        expect(result[:workflow]).to eq(workflow)
      end
    end
  end
end
