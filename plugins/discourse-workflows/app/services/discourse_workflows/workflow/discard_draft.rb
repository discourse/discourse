# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::DiscardDraft
    include Service::Base

    params do
      attribute :workflow_id, :integer

      validates :workflow_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    model :workflow
    model :active_version
    step :restore_published_version
    step :expire_workflow_caches

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_active_version(workflow:)
      workflow.active_version
    end

    def restore_published_version(workflow:, active_version:, guardian:)
      workflow.restore_from_version!(active_version, user: guardian.user)
    end

    def expire_workflow_caches
      Workflow::Action::ExpireCaches.call
    end
  end
end
