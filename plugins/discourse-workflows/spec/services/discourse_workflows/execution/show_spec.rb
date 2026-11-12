# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::Show do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:execution_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow, :discourse_workflows_workflow)
    fab!(:execution) { Fabricate(:discourse_workflows_execution, workflow: workflow) }

    let(:params) { { execution_id: execution.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { execution_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when execution does not exist" do
      let(:params) { { execution_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when everything's ok" do
      it "returns the execution" do
        expect(result).to run_successfully
        expect(result[:execution]).to eq(execution)
      end
    end
  end
end
