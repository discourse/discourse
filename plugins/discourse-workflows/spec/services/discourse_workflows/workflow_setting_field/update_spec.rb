# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowSettingField::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:setting_field_id) }
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_presence_of(:field_type) }

    it do
      is_expected.to validate_inclusion_of(:field_type).in_array(
        DiscourseWorkflows::WorkflowSettingField::FIELD_TYPES,
      )
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }
    fab!(:setting_field) do
      Fabricate(
        :discourse_workflows_workflow_setting_field,
        workflow:,
        key: "priority",
        label: "Priority",
        field_type: "string",
      )
    end

    let(:params) do
      {
        workflow_id: workflow.id,
        setting_field_id: setting_field.id,
        key: "priority",
        label: "Priority Level",
        field_type: "string",
      }
    end
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) do
        { workflow_id: workflow.id, setting_field_id: setting_field.id, key: nil, label: nil }
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

    context "when the setting field does not exist" do
      let(:params) { super().merge(setting_field_id: -1) }

      it { is_expected.to fail_to_find_a_model(:workflow_setting_field) }
    end

    context "when the new key collides with another field on the workflow" do
      before { workflow.setting_fields.create!(key: "other", label: "Other", field_type: "string") }

      let(:params) { super().merge(key: "other") }

      it { is_expected.to fail_with_an_invalid_model(:workflow_setting_field) }
    end

    context "when nothing actually changed" do
      let(:params) do
        {
          workflow_id: workflow.id,
          setting_field_id: setting_field.id,
          key: "priority",
          label: "Priority",
          field_type: "string",
        }
      end

      it { is_expected.to run_successfully }

      it "does not create a new workflow version" do
        expect { result }.not_to change { workflow.reload.version_counter }
      end
    end

    context "when the field type changes to something incompatible with the current value" do
      before { setting_field.update!(value: "hello") }

      let(:params) { super().merge(field_type: "integer") }

      it { is_expected.to fail_a_policy(:existing_value_compatible_with_new_type) }

      it "does not update the field" do
        expect { result }.not_to change { setting_field.reload.field_type }
      end
    end

    context "when the field type changes but the current value is still compatible" do
      before { setting_field.update!(value: "42") }

      let(:params) { super().merge(field_type: "integer") }

      it { is_expected.to run_successfully }

      it "updates the field" do
        expect { result }.to change { setting_field.reload.field_type }.to("integer")
      end
    end

    context "when the field type changes and the current value is blank" do
      let(:params) { super().merge(field_type: "integer") }

      it { is_expected.to run_successfully }
    end

    context "when the definition changed" do
      it { is_expected.to run_successfully }

      it "updates the setting field" do
        expect { result }.to change { setting_field.reload.label }.to("Priority Level")
      end

      it "creates a new workflow version" do
        expect { result }.to change { workflow.reload.version_counter }.by(1)
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_setting_field_updated",
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
