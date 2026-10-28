# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowTest::Destroy do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }
    fab!(:workflow_test) { Fabricate(:discourse_workflows_workflow_test, workflow:) }

    let(:params) { { workflow_id: workflow.id, test_id: workflow_test.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    before { SiteSetting.discourse_workflows_tests_enabled = true }

    context "when the test belongs to another workflow" do
      let(:params) { super().merge(test_id: Fabricate(:discourse_workflows_workflow_test).id) }

      it { is_expected.to fail_to_find_a_model(:workflow_test) }
    end

    it "deletes the test" do
      expect { expect(result).to run_successfully }.to change {
        DiscourseWorkflows::WorkflowTest.count
      }.by(-1)
    end
  end
end
