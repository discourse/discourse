# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSettingField::Destroy
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :setting_field_id, :integer

      validates :workflow_id, :setting_field_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    lock(:workflow_id) do
      model :workflow
      model :workflow_setting_field

      transaction do
        step :destroy_workflow_setting_field
        model :workflow_version, :snapshot_workflow
        step :index_dependencies
      end
    end

    step :log_setting_field_deletion

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_workflow_setting_field(workflow:, params:)
      workflow.setting_fields.find_by(id: params.setting_field_id)
    end

    def destroy_workflow_setting_field(workflow_setting_field:)
      workflow_setting_field.destroy!
    end

    def snapshot_workflow(workflow:, guardian:)
      workflow.snapshot!(user: guardian.user)
    end

    def index_dependencies(workflow:, workflow_version:)
      DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version: workflow_version)
    end

    def log_setting_field_deletion(workflow_setting_field:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_setting_field_destroyed",
        subject: workflow_setting_field.key,
      )
    end
  end
end
