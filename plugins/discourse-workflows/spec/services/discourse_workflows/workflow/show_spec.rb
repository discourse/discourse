# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Show do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }

    let(:params) { { workflow_id: workflow.id } }
    let(:dependencies) { { guardian: user.guardian } }

    context "when params are not valid" do
      let(:params) { { workflow_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when workflow does not exist" do
      let(:params) { { workflow_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "returns the workflow" do
        expect(result[:workflow]).to eq(workflow)
      end
    end
  end
end
