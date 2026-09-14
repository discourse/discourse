# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowVariable::ImportDefinitions do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }

    it "rejects a variables value that isn't an array of hashes" do
      contract = described_class.new(workflow_id: 1, variables: "not-an-array")
      expect(contract).to be_invalid
      expect(contract.errors[:variables]).to be_present
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

    let(:params) do
      {
        workflow_id: workflow.id,
        variables: [
          { "key" => "priority", "variable_type" => "string" },
          { "key" => "notify_categories", "variable_type" => "category_list" },
        ],
      }
    end
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

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates every imported variable" do
        expect { result }.to change { workflow.variables.count }.by(2)
        expect(workflow.variables.pluck(:key)).to contain_exactly("priority", "notify_categories")
      end

      it "sets created_by on every imported variable to the importing admin" do
        result
        expect(workflow.variables.pluck(:created_by_id).uniq).to eq([admin.id])
      end

      it "creates exactly one new workflow version for the whole import" do
        expect { result }.to change { workflow.reload.version_counter }.by(1)
      end

      it "logs a single staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_workflow_variables_imported",
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

    context "when an imported key already exists on the workflow" do
      fab!(:existing_variable) do
        Fabricate(
          :discourse_workflows_workflow_variable,
          workflow:,
          key: "priority",
          variable_type: "enum",
          type_options: {
            "choices" => %w[low high],
          },
        )
      end

      it "skips the colliding variable without touching it" do
        expect { result }.to change { workflow.variables.count }.by(1)
        expect(existing_variable.reload.variable_type).to eq("enum")
      end

      it "reports the skipped key" do
        expect(result[:imported_variables][:skipped]).to eq(["priority"])
      end
    end

    context "when an imported key already exists as a global variable" do
      fab!(:global_variable) { Fabricate(:discourse_workflows_variable, key: "priority") }

      it "still imports it as a workflow-scoped variable" do
        expect { result }.to change { workflow.variables.count }.by(2)
        expect(workflow.variables.pluck(:key)).to include("priority")
        expect(global_variable.reload.workflow_id).to be_nil
      end
    end

    context "when every imported variable is skipped" do
      fab!(:existing_variable) do
        Fabricate(
          :discourse_workflows_workflow_variable,
          workflow:,
          key: "priority",
          variable_type: "string",
        )
      end
      fab!(:existing_notify_variable) do
        Fabricate(
          :discourse_workflows_workflow_variable,
          workflow:,
          key: "notify_categories",
          variable_type: "category_list",
        )
      end

      it "does not create a new workflow version" do
        expect { result }.not_to change { workflow.reload.version_counter }
      end
    end

    context "when variables is empty" do
      let(:params) { super().merge(variables: []) }

      it { is_expected.to run_successfully }

      it "does not create a new workflow version" do
        expect { result }.not_to change { workflow.reload.version_counter }
      end
    end
  end
end
