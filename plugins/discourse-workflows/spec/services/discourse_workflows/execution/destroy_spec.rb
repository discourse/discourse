# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::Destroy do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:workflow, :discourse_workflows_workflow)

    let(:params) { { ids: [execution.id] } }

    before { SiteSetting.discourse_workflows_enabled = true }

    fab!(:execution, :discourse_workflows_execution) do
      Fabricate(:discourse_workflows_execution, workflow: workflow)
    end

    context "when ids are missing" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when valid" do
      it "deletes the executions" do
        expect { result }.to change { DiscourseWorkflows::Execution.count }.by(-1)
      end

      it "returns the deleted count" do
        expect(result[:deleted_count]).to eq(1)
      end
    end
  end
end
