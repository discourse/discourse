# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSettingField::UpdateValue
    include Service::Base

    MAX_VALUE_LENGTH = 10_000

    params do
      attribute :workflow_id, :integer
      attribute :setting_field_id, :integer
      attribute :value, :string

      validates :workflow_id, :setting_field_id, presence: true
      validates :value, length: { maximum: MAX_VALUE_LENGTH }, allow_nil: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    lock(:workflow_id) do
      model :workflow
      model :workflow_setting_field
      policy :value_is_valid, class_name: WorkflowSettingField::Policy::ValueIsValid
      model :draft_was_clean, :capture_draft_was_clean, optional: true

      transaction do
        model :workflow_setting_field, :save_value
        model :workflow_version, :snapshot_workflow
        step :index_dependencies
      end

      # A separate transaction: if publishing fails (e.g. a webhook route
      # collision), the value save above must still stand, matching how a
      # manual Publish click can fail without undoing the draft edit it
      # follows.
      only_if(:should_auto_publish) do
        transaction do
          step :publish_workflow
          step :activate_triggers
        end
      end
    end

    step :expire_workflow_caches

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_workflow_setting_field(workflow:, params:)
      workflow.setting_fields.find_by(id: params.setting_field_id)
    end

    # Must run before the transaction below: snapshot_workflow mutates
    # workflow.version_id, so this is the only point this is knowable.
    def capture_draft_was_clean(workflow:)
      workflow.published? && workflow.version_id == workflow.active_version_id
    end

    def save_value(workflow_setting_field:, params:)
      workflow_setting_field.tap { |field| field.update(value: params.value) }
    end

    def snapshot_workflow(workflow:, guardian:)
      workflow.snapshot!(user: guardian.user)
    end

    def index_dependencies(workflow:, workflow_version:)
      DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version: workflow_version)
    end

    # Passthrough of the pre-transaction value, not a recompute.
    def should_auto_publish(draft_was_clean:)
      draft_was_clean
    end

    def publish_workflow(workflow:, guardian:)
      workflow.publish!(user: guardian.user)
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

    def expire_workflow_caches
      Workflow::Action::ExpireCaches.call
    end
  end
end
