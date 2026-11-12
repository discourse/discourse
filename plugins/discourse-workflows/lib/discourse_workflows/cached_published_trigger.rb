# frozen_string_literal: true

module DiscourseWorkflows
  CachedPublishedTrigger =
    Data.define(:workflow_id, :workflow_version_id, :trigger_node) do
      def self.from_hash(hash)
        attrs = hash.with_indifferent_access

        new(
          workflow_id: attrs[:workflow_id],
          workflow_version_id: attrs[:workflow_version_id],
          trigger_node: attrs[:trigger_node],
        )
      end

      def trigger_node_id
        trigger_node["id"]
      end

      def to_h
        {
          workflow_id: workflow_id,
          workflow_version_id: workflow_version_id,
          trigger_node: trigger_node,
        }
      end
    end
end
