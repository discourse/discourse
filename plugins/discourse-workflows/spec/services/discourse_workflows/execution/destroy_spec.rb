# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:execution_ids) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, guardian:) }

    fab!(:admin)
    fab!(:workflow, :discourse_workflows_workflow)
    fab!(:execution) { Fabricate(:discourse_workflows_execution, workflow: workflow) }

    let(:params) { { execution_ids: [execution.id] } }
    let(:guardian) { admin.guardian }

    context "when contract is not valid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when execution_ids exceeds the maximum" do
      let(:params) do
        { execution_ids: (1..(DiscourseWorkflows::Execution::Destroy::MAX_BULK_DELETE + 1)).to_a }
      end

      it { is_expected.to fail_a_contract }
    end

    context "when user is not admin" do
      fab!(:user)

      let(:guardian) { user.guardian }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "deletes the executions" do
        expect { result }.to change { DiscourseWorkflows::Execution.count }.by(-1)
      end

      it "deletes associated execution data" do
        Fabricate(:discourse_workflows_execution_data, execution: execution)

        expect { result }.to change { DiscourseWorkflows::ExecutionData.count }.by(-1)
      end

      it "returns the deleted count" do
        expect(result[:deleted_count]).to eq(1)
      end
    end
  end
end
