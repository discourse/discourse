# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:ids) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:workflow, :discourse_workflows_workflow)
    fab!(:execution, :discourse_workflows_execution) do
      Fabricate(:discourse_workflows_execution, workflow: workflow)
    end

    let(:params) { { ids: [execution.id] } }

    context "when contract is not valid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "deletes the executions" do
        expect { result }.to change { DiscourseWorkflows::Execution.count }.by(-1)
      end

      it "returns the deleted count" do
        expect(result[:deleted_count]).to eq(1)
      end
    end
  end
end
