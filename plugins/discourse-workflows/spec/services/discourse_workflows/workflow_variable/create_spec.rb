# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowVariable::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_presence_of(:variable_type) }
    it { is_expected.to validate_length_of(:key).is_at_most(100) }
    it { is_expected.to validate_length_of(:description).is_at_most(500) }

    it do
      is_expected.to validate_inclusion_of(:variable_type).in_array(
        DiscourseWorkflows::Variable::VARIABLE_TYPES,
      )
    end

    it { is_expected.to allow_values("valid_key", "Key_123", "_underscore").for(:key) }
    it { is_expected.not_to allow_values("invalid key", "123start", "key!@#").for(:key) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

    let(:params) { { workflow_id: workflow.id, key: "priority", variable_type: "string" } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { workflow_id: workflow.id, key: "invalid key!", variable_type: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when the workflow does not exist" do
      let(:params) { super().merge(workflow_id: -1) }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when the key is already used on that workflow" do
      before do
        workflow.variables.create!(key: "priority", variable_type: "string", created_by: admin)
      end

      it { is_expected.to fail_with_an_invalid_model(:variable) }
    end

    context "when the key is already used by a global variable" do
      before { Fabricate(:discourse_workflows_variable, key: "priority") }

      it { is_expected.to run_successfully }
    end

    context "when variable_type is enum without choices" do
      let(:params) { super().merge(variable_type: "enum") }

      it { is_expected.to fail_with_an_invalid_model(:variable) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates the variable, scoped to the workflow" do
        expect { result }.to change { workflow.variables.count }.by(1)
        expect(workflow.variables.last).to have_attributes(
          key: "priority",
          variable_type: "string",
          workflow_id: workflow.id,
        )
      end

      it "derives the label from the key" do
        result
        expect(workflow.variables.last.label).to eq("Priority")
      end

      it "does not affect global variables" do
        expect { result }.not_to change {
          DiscourseWorkflows::Variable.where(workflow_id: nil).count
        }
      end

      it "creates a new workflow version" do
        expect { result }.to change { workflow.reload.version_counter }.by(1)
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_workflow_variable_created",
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
