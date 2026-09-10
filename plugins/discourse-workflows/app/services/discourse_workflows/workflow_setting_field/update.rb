# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSettingField::Update
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :setting_field_id, :integer
      attribute :key, :string
      attribute :label, :string
      attribute :description, :string
      attribute :field_type, :string
      attribute :type_options, default: -> { {} }

      validates :workflow_id, :setting_field_id, presence: true
      validates :key,
                presence: true,
                length: {
                  maximum: 100,
                },
                format: {
                  with: /\A[a-zA-Z_][a-zA-Z0-9_]*\z/,
                }
      validates :label, presence: true, length: { maximum: 255 }
      validates :description, length: { maximum: 500 }, allow_nil: true
      validates :field_type,
                presence: true,
                inclusion: {
                  in: DiscourseWorkflows::WorkflowSettingField::FIELD_TYPES,
                }
      validate :type_options_is_a_hash

      def type_options_is_a_hash
        errors.add(:type_options, :invalid) unless type_options.is_a?(Hash)
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    lock(:workflow_id) do
      model :workflow
      model :workflow_setting_field
      model :previous_definition, :capture_previous_definition
      only_if(:field_type_or_options_changing) do
        policy :existing_value_compatible_with_new_type,
               class_name: WorkflowSettingField::Policy::ExistingValueCompatibleWithNewType
      end

      transaction do
        model :workflow_setting_field, :save_workflow_setting_field
        only_if(:definition_changed) do
          model :workflow_version, :snapshot_workflow
          step :index_dependencies
        end
      end
    end

    step :log_setting_field_update

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_workflow_setting_field(workflow:, params:)
      workflow.setting_fields.find_by(id: params.setting_field_id)
    end

    def capture_previous_definition(workflow_setting_field:)
      workflow_setting_field.definition
    end

    def field_type_or_options_changing(workflow_setting_field:, params:)
      workflow_setting_field.field_type != params.field_type ||
        workflow_setting_field.type_options != params.type_options
    end

    def save_workflow_setting_field(workflow_setting_field:, params:)
      workflow_setting_field.tap do |field|
        field.assign_attributes(
          key: params.key,
          label: params.label,
          description: params.description,
          field_type: params.field_type,
          type_options: params.type_options,
        )
        field.save
      end
    end

    def definition_changed(workflow_setting_field:, previous_definition:)
      workflow_setting_field.definition != previous_definition
    end

    def snapshot_workflow(workflow:, guardian:)
      workflow.snapshot!(user: guardian.user)
    end

    def index_dependencies(workflow:, workflow_version:)
      DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version: workflow_version)
    end

    def log_setting_field_update(workflow_setting_field:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_setting_field_updated",
        subject: workflow_setting_field.key,
      )
    end
  end
end
