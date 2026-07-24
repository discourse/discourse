# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Action::FindPublishedTriggers < Service::ActionBase
    option :trigger_type
    option :dependency_type, default: -> { "node_type" }
    option :dependency_key, default: -> { trigger_type }
    option :filter, optional: true

    def call
      workflow_node_pairs.filter_map do |workflow_id, workflow_version_id, node_id|
        workflow = workflows_by_id[workflow_id]
        version = versions_by_id[workflow_version_id]
        node = version&.nodes&.find { |candidate| candidate["id"] == node_id.to_s }
        next unless node&.dig("type") == trigger_type

        published_trigger =
          DiscourseWorkflows::PublishedTrigger.new(
            workflow: workflow,
            workflow_version: version,
            trigger_node: node,
          )
        next if filter && !filter.call(published_trigger)

        published_trigger
      end
    end

    private

    def workflow_node_pairs
      @workflow_node_pairs ||=
        WorkflowDependency
          .joins(:workflow)
          .where(dependency_type: dependency_type, dependency_key: dependency_key.to_s)
          .where(
            "discourse_workflows_workflows.active_version_id = " \
              "discourse_workflows_workflow_dependencies.workflow_version_id",
          )
          .pluck(:workflow_id, :workflow_version_id, :node_id)
    end

    def workflows_by_id
      @workflows_by_id ||=
        Workflow
          .includes(:active_version)
          .where(id: workflow_node_pairs.map(&:first).uniq)
          .index_by(&:id)
    end

    def versions_by_id
      @versions_by_id ||=
        WorkflowVersion.where(version_id: workflow_node_pairs.map(&:second).uniq).index_by(
          &:version_id
        )
    end
  end
end
