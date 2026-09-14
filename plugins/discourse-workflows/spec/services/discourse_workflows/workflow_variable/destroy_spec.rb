# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowVariable::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:variable_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }
    fab!(:variable) do
      Fabricate(
        :discourse_workflows_workflow_variable,
        workflow:,
        key: "priority",
        variable_type: "string",
      )
    end

    let(:params) { { workflow_id: workflow.id, variable_id: variable.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when the workflow does not exist" do
      let(:params) { super().merge(workflow_id: -1) }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when the variable does not exist" do
      let(:params) { super().merge(variable_id: -1) }

      it { is_expected.to fail_to_find_a_model(:variable) }
    end

    context "when the variable is actually a global variable" do
      fab!(:global_variable) { Fabricate(:discourse_workflows_variable, key: "global_one") }

      let(:params) { super().merge(variable_id: global_variable.id) }

      it { is_expected.to fail_to_find_a_model(:variable) }

      it "does not destroy the global variable" do
        expect { result }.not_to change {
          DiscourseWorkflows::Variable.where(workflow_id: nil).count
        }
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "destroys the variable" do
        expect { result }.to change { workflow.variables.count }.by(-1)
      end

      it "creates a new workflow version" do
        expect { result }.to change { workflow.reload.version_counter }.by(1)
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_workflow_variable_destroyed",
          subject: "priority",
        )
      end

      it "indexes workflow dependencies for the new version" do
        error_workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
        workflow.update!(error_workflow_id: error_workflow.id)

        expect(result).to run_successfully

        dependency =
          DiscourseWorkflows::WorkflowDependency.find_by(
            workflow_version_id: result.workflow_version.version_id,
            dependency_type: "error_workflow",
          )
        expect(dependency).to be_present
        expect(dependency.dependency_key).to eq(error_workflow.id.to_s)
      end
    end
  end
end
