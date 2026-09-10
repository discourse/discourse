# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowSettingField::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_presence_of(:label) }
    it { is_expected.to validate_presence_of(:field_type) }
    it { is_expected.to validate_length_of(:key).is_at_most(100) }
    it { is_expected.to validate_length_of(:label).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(500) }

    it do
      is_expected.to validate_inclusion_of(:field_type).in_array(
        DiscourseWorkflows::WorkflowSettingField::FIELD_TYPES,
      )
    end

    it { is_expected.to allow_values("valid_key", "Key_123", "_underscore").for(:key) }
    it { is_expected.not_to allow_values("invalid key", "123start", "key!@#").for(:key) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

    let(:params) do
      { workflow_id: workflow.id, key: "priority", label: "Priority", field_type: "string" }
    end
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { workflow_id: workflow.id, key: "invalid key!", label: nil } }

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
        workflow.setting_fields.create!(key: "priority", label: "Existing", field_type: "string")
      end

      it { is_expected.to fail_with_an_invalid_model(:workflow_setting_field) }
    end

    context "when field_type is enum without choices" do
      let(:params) { super().merge(field_type: "enum") }

      it { is_expected.to fail_with_an_invalid_model(:workflow_setting_field) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates the setting field" do
        expect { result }.to change { workflow.setting_fields.count }.by(1)
        expect(workflow.setting_fields.last).to have_attributes(
          key: "priority",
          label: "Priority",
          field_type: "string",
        )
      end

      it "creates a new workflow version" do
        expect { result }.to change { workflow.reload.version_counter }.by(1)
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_setting_field_created",
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
