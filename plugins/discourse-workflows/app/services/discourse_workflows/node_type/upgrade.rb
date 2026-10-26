# frozen_string_literal: true

module DiscourseWorkflows
  # Upgrades the deprecated nodes an editor sends without saving them, so its unsaved edits are kept.
  class NodeType::Upgrade
    include Service::Base

    params do
      attribute :nodes, :array

      validates :nodes, presence: true

      def saved_nodes
        nodes.map { |node| node.to_h.deep_stringify_keys }
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :upgrade, :upgrade_nodes

    private

    def upgrade_nodes(params:)
      NodeUpgrader.call(params.saved_nodes)
    end
  end
end
