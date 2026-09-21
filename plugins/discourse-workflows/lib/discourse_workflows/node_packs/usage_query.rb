# frozen_string_literal: true

module DiscourseWorkflows
  module NodePacks
    class UsageQuery
      LIVE_EXECUTION_STATUSES = %i[pending running waiting].freeze

      def initialize(identifiers)
        @identifiers = identifiers.uniq
      end

      def workflows
        workflow_rows.map { |workflow| workflow.except(:node_types) }
      end

      def node_usage_counts
        workflow_rows.flat_map { |workflow| workflow[:node_types] }.tally
      end

      def workflow_usage_count(identifiers)
        identifiers = identifiers.to_set
        workflow_rows.count do |workflow|
          workflow[:node_types].any? { |node_type| identifiers.include?(node_type) }
        end
      end

      def active_executions
        return 0 if @identifiers.empty?

        Execution
          .where(status: LIVE_EXECUTION_STATUSES)
          .joins(<<~SQL)
            LEFT JOIN discourse_workflows_workflow_versions versions
              ON versions.version_id = discourse_workflows_executions.workflow_version_id
            LEFT JOIN discourse_workflows_execution_data execution_data
              ON execution_data.execution_id = discourse_workflows_executions.id
          SQL
          .where(<<~SQL, @identifiers)
            EXISTS (
              SELECT 1
              FROM jsonb_array_elements(
                COALESCE(execution_data.workflow_data->'nodes', versions.nodes, '[]'::jsonb)
              ) node
              WHERE node->>'type' IN (?)
            )
          SQL
          .count
      end

      private

      def workflow_rows
        return [] if @identifiers.empty?

        @workflow_rows ||=
          Workflow
            .joins(<<~SQL)
              LEFT JOIN discourse_workflows_workflow_versions active_versions
                ON active_versions.version_id = discourse_workflows_workflows.active_version_id
              CROSS JOIN LATERAL (
                SELECT draft_node AS node, FALSE AS published
                FROM jsonb_array_elements(discourse_workflows_workflows.nodes) draft_node
                UNION ALL
                SELECT active_node AS node, TRUE AS published
                FROM jsonb_array_elements(COALESCE(active_versions.nodes, '[]'::jsonb)) active_node
              ) referenced_nodes
            SQL
            .where("referenced_nodes.node->>'type' IN (?)", @identifiers)
            .group("discourse_workflows_workflows.id", "discourse_workflows_workflows.name")
            .pluck(
              "discourse_workflows_workflows.id",
              "discourse_workflows_workflows.name",
              Arel.sql("BOOL_OR(referenced_nodes.published)"),
              Arel.sql("ARRAY_REMOVE(ARRAY_AGG(DISTINCT referenced_nodes.node->>'id'), NULL)"),
              Arel.sql("ARRAY_AGG(DISTINCT referenced_nodes.node->>'type')"),
            )
            .map do |id, name, published, node_ids, node_types|
              { id:, name:, published:, node_ids:, node_types: }
            end
      end
    end
  end
end
