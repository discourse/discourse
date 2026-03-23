# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Show do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:user)
    fab!(:workflow, :discourse_workflows_workflow) do
      Fabricate(:discourse_workflows_workflow, created_by: user)
    end

    let(:params) { { workflow_id: workflow.id } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when workflow does not exist" do
      let(:params) { { workflow_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when workflow exists" do
      it { is_expected.to run_successfully }

      it "returns the workflow" do
        expect(result[:workflow]).to eq(workflow)
      end
    end
  end
end
