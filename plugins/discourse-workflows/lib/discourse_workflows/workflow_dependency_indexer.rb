# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowDependencyIndexer
    def self.call(
      workflow,
      version: workflow.workflow_versions.find_by(version_id: workflow.version_id)
    )
      new(workflow, version:).call
    end

    def initialize(workflow, version:)
      @workflow = workflow
      @version = version
    end

    def call
      return unless @version

      rows = []

      @version.nodes.each do |node|
        node_id = node["id"]
        node_type = node["type"]
        parameters = NodeData.parameters(node)
        split =
          NodeData.split(
            parameters: parameters,
            credentials: NodeData.credentials(node),
            node_type: node_type,
          )
        credentials = split["credentials"]

        rows << build_row("node_type", node_type, node_id) if node_type.present?

        credentials.each_value do |credential|
          rows << build_row("credential_id", credential["id"], node_id) if credential["id"].present?
        end

        if (dt_id = parameters["data_table_id"]).present?
          rows << build_row("data_table_id", dt_id, node_id)
        end

        if node_type == DiscourseWorkflows::Nodes::WorkflowCall::V1.identifier &&
             (workflow_id = parameters["workflow_id"]).present?
          rows << build_row("workflow_call", workflow_id, node_id)
        end
      end

      if @workflow.error_workflow_id.present?
        rows << build_row("error_workflow", @workflow.error_workflow_id, nil)
      end

      @workflow.with_lock do
        WorkflowDependency.where(workflow_version_id: @version.version_id).delete_all

        WorkflowDependency.insert_all(rows) if rows.present?
      end

      WorkflowDependency.clear_cache!
    end

    private

    def build_row(type, key, node_id)
      {
        workflow_id: @workflow.id,
        dependency_type: type,
        dependency_key: key.to_s,
        node_id: node_id,
        workflow_version_id: @version.version_id,
        created_at: Time.current,
      }
    end
  end
end
