# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    # Shared mutable static-data state for a single workflow execution.
    #
    # Lifecycle:
    #   1. Snapshotted from the workflow row at execution start (`from_workflow`).
    #   2. Read/mutated through `get_workflow_static_data` from any node's
    #      execution context during the run.
    #   3. Committed back to the workflow row at execution end via
    #      `Executor#commit_static_data!`. Commits are skipped when no node
    #      ever accessed the data (`dirty?` stays false).
    #
    # Concurrency: commits take a row lock and reload the workflow, then
    # overwrite `global` (last-write-wins) and merge `node` by
    # name, persisted as flat `node:<name>` keys, so concurrent executions
    # writing to different nodes don't clobber each other.
    class StaticDataState
      attr_reader :global, :node

      def self.from_workflow(workflow)
        normalized = workflow.normalized_static_data
        new(
          global: normalized[DiscourseWorkflows::Workflow::STATIC_DATA_GLOBAL_KEY].deep_dup,
          node: workflow.node_static_data_entries.deep_dup,
        )
      end

      def initialize(global: {}, node: {})
        @global = global || {}
        @node = node || {}
        @dirty = false
      end

      def dirty?
        @dirty
      end

      def fetch(scope)
        @dirty = true
        case scope.to_s
        when DiscourseWorkflows::Workflow::STATIC_DATA_GLOBAL_KEY
          @global
        when "node"
          raise ArgumentError, "Node scope requires a node name (use fetch_node(name))"
        else
          raise ArgumentError, "Unknown static data scope: #{scope.inspect}. Use :node or :global"
        end
      end

      def fetch_node(node_name)
        @dirty = true
        key = node_name.to_s
        @node[key] = {} unless @node.key?(key)
        @node[key]
      end
    end
  end
end
