# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowVariable::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:variable_id) }
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_presence_of(:variable_type) }

    it do
      is_expected.to validate_inclusion_of(:variable_type).in_array(
        DiscourseWorkflows::Variable::VARIABLE_TYPES,
      )
    end
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

    let(:params) do
      {
        workflow_id: workflow.id,
        variable_id: variable.id,
        key: "priority_level",
        variable_type: "string",
      }
    end
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) do
        { workflow_id: workflow.id, variable_id: variable.id, key: nil, variable_type: nil }
      end

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

    context "when the variable does not exist" do
      let(:params) { super().merge(variable_id: -1) }

      it { is_expected.to fail_to_find_a_model(:variable) }
    end

    context "when the variable belongs to another workflow" do
      fab!(:other_workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }
      fab!(:other_variable) do
        Fabricate(:discourse_workflows_workflow_variable, workflow: other_workflow, key: "other")
      end

      let(:params) { super().merge(variable_id: other_variable.id) }

      it { is_expected.to fail_to_find_a_model(:variable) }
    end

    context "when the variable is actually a global variable" do
      fab!(:global_variable) { Fabricate(:discourse_workflows_variable, key: "global_one") }

      let(:params) { super().merge(variable_id: global_variable.id) }

      it { is_expected.to fail_to_find_a_model(:variable) }
    end

    context "when the new key collides with another variable on the workflow" do
      before do
        workflow.variables.create!(key: "other", variable_type: "string", created_by: admin)
      end

      let(:params) { super().merge(key: "other") }

      it { is_expected.to fail_with_an_invalid_model(:variable) }
    end

    context "when the new key collides with a global variable's key" do
      before { Fabricate(:discourse_workflows_variable, key: "priority_level") }

      it { is_expected.to run_successfully }
    end

    context "when nothing actually changed" do
      let(:params) do
        {
          workflow_id: workflow.id,
          variable_id: variable.id,
          key: "priority",
          variable_type: "string",
        }
      end

      it { is_expected.to run_successfully }

      it "does not create a new workflow version" do
        expect { result }.not_to change { workflow.reload.version_counter }
      end
    end

    context "when the variable type changes to something incompatible with the current value" do
      before { variable.update!(value: "hello") }

      let(:params) { super().merge(variable_type: "integer") }

      it { is_expected.to fail_a_policy(:existing_value_compatible_with_new_type) }

      it "does not update the variable" do
        expect { result }.not_to change { variable.reload.variable_type }
      end
    end

    context "when the variable type changes but the current value is still compatible" do
      before { variable.update!(value: "42") }

      let(:params) { super().merge(variable_type: "integer") }

      it { is_expected.to run_successfully }

      it "updates the variable" do
        expect { result }.to change { variable.reload.variable_type }.to("integer")
      end
    end

    context "when the variable type changes and the current value is blank" do
      let(:params) { super().merge(variable_type: "integer") }

      it { is_expected.to run_successfully }
    end

    context "when the definition changed" do
      it { is_expected.to run_successfully }

      it "updates the variable" do
        expect { result }.to change { variable.reload.key }.to("priority_level")
      end

      it "the derived label reflects the new key" do
        result
        expect(variable.reload.label).to eq("Priority level")
      end

      it "creates a new workflow version" do
        expect { result }.to change { workflow.reload.version_counter }.by(1)
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_workflow_variable_updated",
          subject: "priority_level",
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
