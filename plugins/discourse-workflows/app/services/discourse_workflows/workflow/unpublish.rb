# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Unpublish
    include Service::Base

    params do
      attribute :workflow_id, :integer

      validates :workflow_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    lock(:workflow_id) do
      model :workflow
      step :deactivate_triggers
      step :unpublish_workflow
    end

    step :expire_workflow_caches

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def unpublish_workflow(workflow:, guardian:)
      workflow.unpublish!(user: guardian.user)
    end

    def deactivate_triggers(workflow:)
      TriggerRuntime.deactivate_workflow!(workflow)
    end

    def expire_workflow_caches
      Workflow::Action::ExpireCaches.call
    end
  end
end
