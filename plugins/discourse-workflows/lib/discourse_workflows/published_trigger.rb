# frozen_string_literal: true

module DiscourseWorkflows
  PublishedTrigger =
    Data.define(:workflow, :workflow_version, :trigger_node) do
      # The node `node_id` of workflow `workflow_id` when its type is `type`: from the published
      # version, or from the unpublished draft when `draft` is set, which only a guardian who can
      # manage workflows may resolve.
      def self.find(type:, workflow_id:, node_id:, draft: false, guardian: nil)
        # A blank ID would otherwise widen the published lookup to every trigger of that type.
        return if workflow_id.blank? || node_id.blank?

        if !draft
          return(
            Workflow::Action::FindPublishedTriggers.call(
              trigger_type: type,
              workflow_id:,
              node_id:,
            ).first
          )
        end
        return if !guardian&.can_manage_workflows?

        workflow = Workflow.find_by(id: workflow_id)
        trigger_node = workflow&.find_node(node_id)
        new(workflow:, workflow_version: nil, trigger_node:) if trigger_node&.dig("type") == type
      end

      def workflow_id
        workflow.id
      end

      def workflow_version_id
        workflow_version.id
      end

      def trigger_node_id
        trigger_node["id"]
      end

      def draft?
        workflow_version.nil?
      end

      def parameters
        NodeData.parameters(trigger_node)
      end

      def node_type
        NodeData.node_type(trigger_node)
      end

      def workflow_name
        workflow_version&.name || workflow.name
      end
    end
end
