# frozen_string_literal: true

module DiscourseWorkflows
  class NodePack::Remove
    include Service::Base

    params do
      attribute :node_pack_id, :integer
      validates :node_pack_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :node_pack

    transaction do
      step :lock_pack_lifecycle
      model :usage
      policy :not_in_use
      step :remove_pack
    end

    step :bump_runtime_version
    step :log_removal

    private

    def fetch_node_pack(params:)
      NodePack.installed.includes(:definitions).find_by(id: params.node_pack_id)
    end

    def lock_pack_lifecycle(node_pack:)
      NodePacks::LifecycleLock.lock_keys!([node_pack.key])
    end

    def fetch_usage(node_pack:)
      query = NodePacks::UsageQuery.new(node_pack.definitions.map(&:identifier))
      { referencing_workflows: query.workflows, active_executions: query.active_executions }
    end

    def not_in_use(usage:)
      context[:referencing_workflows] = usage[:referencing_workflows]
      context[:active_executions] = usage[:active_executions]
      context[:error_type] = "node_pack_in_use"
      usage[:referencing_workflows].empty? && usage[:active_executions].zero?
    end

    def remove_pack(node_pack:)
      now = Time.current
      node_pack.definitions.where(retired_at: nil).update_all(retired_at: now, updated_at: now)
      node_pack.update!(removed_at: now, enabled: false, palette_visible: false)
    end

    def bump_runtime_version
      NodePacks::Runtime.bump!
    end

    def log_removal(node_pack:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_node_pack_removed",
        subject: node_pack.key,
      )
    end
  end
end
