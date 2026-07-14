# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Publish
    include Service::Base

    params do
      attribute :workflow_id, :integer

      validates :workflow_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    lock(:workflow_id) do
      model :workflow

      transaction do
        model :workflow_version
        step :publish_workflow
        step :activate_triggers
      end
    end

    step :expire_workflow_caches

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_workflow_version(workflow:)
      workflow.workflow_versions.find_by(version_id: workflow.version_id)
    end

    def publish_workflow(workflow:, guardian:)
      workflow.publish!(user: guardian.user)
    end

    def expire_workflow_caches
      Workflow::Action::ExpireCaches.call
    end

    def activate_triggers(workflow:, workflow_version:)
      TriggerRuntime.activate_workflow!(workflow, workflow_version: workflow_version)
    rescue Webhook::Action::ActivateWebhooks::CollisionError => e
      fail!(
        I18n.t(
          "discourse_workflows.errors.webhook_route_collision",
          method: e.method,
          path: "/#{e.path}",
        ),
      )
    end
  end
end
