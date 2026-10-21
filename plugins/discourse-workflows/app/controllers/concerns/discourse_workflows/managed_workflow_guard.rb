# frozen_string_literal: true

module DiscourseWorkflows
  module ManagedWorkflowGuard
    extend ActiveSupport::Concern

    private

    def ensure_workflow_editable
      workflow_id = params[:workflow_id] || params[:id]
      workflow = DiscourseWorkflows::Workflow.find_by(id: workflow_id)
      return unless workflow&.managed_by

      render json: {
               errors: [I18n.t("discourse_workflows.errors.managed_workflow_read_only")],
             },
             status: :forbidden
    end
  end
end
