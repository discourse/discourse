# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Destroy
    include Service::Base

    params { attribute :workflow_id, :integer }

    model :workflow
    step :log
    step :destroy_workflow
    step :clear_site_cache

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def log(workflow:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_workflow_destroyed",
        subject: workflow.name,
        workflow_id: workflow.id,
      )
    end

    def destroy_workflow(workflow:)
      workflow.destroy!
    end

    def clear_site_cache
      Site.clear_cache
    end
  end
end
