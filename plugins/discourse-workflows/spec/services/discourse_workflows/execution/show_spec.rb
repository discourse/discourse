# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::Show do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:workflow, :discourse_workflows_workflow)
    fab!(:execution, :discourse_workflows_execution) do
      Fabricate(:discourse_workflows_execution, workflow: workflow)
    end

    let(:params) { { execution_id: execution.id } }

    context "when execution does not exist" do
      let(:params) { { execution_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "returns the execution" do
        expect(result[:execution]).to eq(execution)
      end
    end
  end
end
