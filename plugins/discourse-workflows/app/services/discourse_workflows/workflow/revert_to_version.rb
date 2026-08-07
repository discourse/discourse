# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::RevertToVersion
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :version_id, :string

      validates :workflow_id, presence: true
      validates :version_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    model :workflow
    model :version
    step :restore_version
    step :expire_workflow_caches

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_version(workflow:, params:)
      workflow.workflow_versions.find_by(version_id: params.version_id)
    end

    def restore_version(workflow:, version:, guardian:)
      workflow.restore_from_version!(version, user: guardian.user)
    end

    def expire_workflow_caches
      Workflow::Action::ExpireCaches.call
    end
  end
end
