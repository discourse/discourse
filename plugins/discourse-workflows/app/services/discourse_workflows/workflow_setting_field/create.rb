# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSettingField::Create
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :key, :string
      attribute :label, :string
      attribute :description, :string
      attribute :field_type, :string
      attribute :type_options, default: -> { {} }

      validates :workflow_id, presence: true
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

      transaction do
        model :workflow_setting_field, :create_workflow_setting_field
        model :workflow_version, :snapshot_workflow
        step :index_dependencies
      end
    end

    step :log_setting_field_creation

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def create_workflow_setting_field(workflow:, params:)
      workflow.setting_fields.create(
        key: params.key,
        label: params.label,
        description: params.description,
        field_type: params.field_type,
        type_options: params.type_options,
      )
    end

    def snapshot_workflow(workflow:, guardian:)
      workflow.snapshot!(user: guardian.user)
    end

    def index_dependencies(workflow:, workflow_version:)
      DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version: workflow_version)
    end

    def log_setting_field_creation(workflow_setting_field:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_setting_field_created",
        subject: workflow_setting_field.key,
      )
    end
  end
end
