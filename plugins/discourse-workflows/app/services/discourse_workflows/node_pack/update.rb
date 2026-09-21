# frozen_string_literal: true

module DiscourseWorkflows
  class NodePack::Update
    include Service::Base

    params do
      attribute :node_pack_id, :integer
      attribute :enabled, :boolean
      attribute :palette_visible, :boolean
      validates :node_pack_id, presence: true
      validate :at_least_one_change

      def at_least_one_change
        errors.add(:base, :invalid) if enabled.nil? && palette_visible.nil?
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :node_pack

    transaction do
      step :lock_pack_lifecycle
      step :apply_changes
    end

    step :bump_runtime_version
    step :log_change

    private

    def fetch_node_pack(params:)
      NodePack.installed.includes(:definitions, :installed_by).find_by(id: params.node_pack_id)
    end

    def lock_pack_lifecycle(node_pack:)
      NodePacks::LifecycleLock.lock_keys!([node_pack.key])
    end

    def apply_changes(node_pack:, params:, guardian:)
      changes = { updated_by_id: guardian.user.id }
      changes[:enabled] = params.enabled unless params.enabled.nil?
      changes[:palette_visible] = params.palette_visible unless params.palette_visible.nil?
      node_pack.update!(changes)
    end

    def bump_runtime_version
      NodePacks::Runtime.bump!
    end

    def log_change(node_pack:, params:, guardian:)
      actions = []
      actions << (params.enabled ? "enabled" : "disabled") unless params.enabled.nil?
      actions << (params.palette_visible ? "shown" : "hidden") unless params.palette_visible.nil?
      actions.each do |action|
        StaffActionLogger.new(guardian.user).log_custom(
          "discourse_workflows_node_pack_#{action}",
          subject: node_pack.key,
        )
      end
    end
  end
end
