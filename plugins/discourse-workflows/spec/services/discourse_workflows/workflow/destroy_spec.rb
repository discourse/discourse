# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Destroy do
  describe ".call" do
    subject(:result) { described_class.call(params:, guardian: user.guardian) }

    fab!(:user, :admin)
    fab!(:workflow, :discourse_workflows_workflow) do
      Fabricate(:discourse_workflows_workflow, created_by: user)
    end

    let(:params) { { workflow_id: workflow.id } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when workflow does not exist" do
      let(:params) { { workflow_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "deletes the workflow" do
        result
        expect(DiscourseWorkflows::Workflow.exists?(workflow.id)).to eq(false)
      end

      it "deletes associated nodes" do
        Fabricate(:discourse_workflows_node, workflow: workflow)
        expect { result }.to change { DiscourseWorkflows::Node.count }.by(-1)
      end

      it "deletes associated connections" do
        Fabricate(:discourse_workflows_connection, workflow: workflow)
        expect { result }.to change { DiscourseWorkflows::Connection.count }.by(-1)
      end

      it "deletes associated executions" do
        Fabricate(:discourse_workflows_execution, workflow: workflow)
        expect { result }.to change { DiscourseWorkflows::Execution.count }.by(-1)
      end

      it "logs a staff action" do
        result
        log = UserHistory.last
        expect(log.custom_type).to eq("discourse_workflows_workflow_destroyed")
        expect(log.subject).to eq(workflow.name)
      end
    end
  end
end
