# frozen_string_literal: true

module DiscourseWorkflows
  PublishedTrigger =
    Data.define(:workflow, :workflow_version, :trigger_node) do
      def workflow_id
        workflow.id
      end

      def workflow_version_id
        workflow_version.id
      end

      def trigger_node_id
        trigger_node["id"]
      end
    end
end
