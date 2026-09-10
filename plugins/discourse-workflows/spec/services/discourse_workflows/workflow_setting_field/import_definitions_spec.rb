# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowSettingField::ImportDefinitions do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }

    it "rejects a setting_fields value that isn't an array of hashes" do
      contract = described_class.new(workflow_id: 1, setting_fields: "not-an-array")
      expect(contract).to be_invalid
      expect(contract.errors[:setting_fields]).to be_present
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

    let(:params) do
      {
        workflow_id: workflow.id,
        setting_fields: [
          { "key" => "priority", "label" => "Priority", "field_type" => "string" },
          {
            "key" => "notify_categories",
            "label" => "Notify categories",
            "field_type" => "category_list",
          },
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

      it "creates every imported field" do
        expect { result }.to change { workflow.setting_fields.count }.by(2)
        expect(workflow.setting_fields.pluck(:key)).to contain_exactly(
          "priority",
          "notify_categories",
        )
      end

      it "creates exactly one new workflow version for the whole import" do
        expect { result }.to change { workflow.reload.version_counter }.by(1)
      end

      it "logs a single staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_setting_fields_imported",
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
      fab!(:existing_field) do
        Fabricate(
          :discourse_workflows_workflow_setting_field,
          workflow:,
          key: "priority",
          label: "Existing priority",
          field_type: "enum",
          type_options: {
            "choices" => %w[low high],
          },
        )
      end

      it "skips the colliding field without touching it" do
        expect { result }.to change { workflow.setting_fields.count }.by(1)
        expect(existing_field.reload.label).to eq("Existing priority")
      end

      it "reports the skipped key" do
        expect(result[:imported_fields][:skipped]).to eq(["priority"])
      end
    end

    context "when every imported field is skipped" do
      fab!(:existing_field) do
        Fabricate(
          :discourse_workflows_workflow_setting_field,
          workflow:,
          key: "priority",
          label: "Existing priority",
          field_type: "string",
        )
      end
      fab!(:existing_notify_field) do
        Fabricate(
          :discourse_workflows_workflow_setting_field,
          workflow:,
          key: "notify_categories",
          label: "Existing notify categories",
          field_type: "category_list",
        )
      end

      it "does not create a new workflow version" do
        expect { result }.not_to change { workflow.reload.version_counter }
      end
    end

    context "when setting_fields is empty" do
      let(:params) { super().merge(setting_fields: []) }

      it { is_expected.to run_successfully }

      it "does not create a new workflow version" do
        expect { result }.not_to change { workflow.reload.version_counter }
      end
    end
  end
end
