# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :enabled,
               :nodes,
               :connections,
               :error_workflow_id,
               :error_workflow_name,
               :run_as_username,
               :created_at,
               :updated_at,
               :last_execution_status,
               :last_execution_at,
               :last_execution_node_outputs

    attribute :created_by
    attribute :updated_by

    def nodes
      (object.parsed_nodes || []).sort_by { |n| n["position_index"] || 0 }
    end

    def connections
      object.parsed_connections || []
    end

    def created_by
      BasicUserSerializer.new(object.created_by, root: false).as_json
    end

    def updated_by
      return if object.updated_by.blank?
      BasicUserSerializer.new(object.updated_by, root: false).as_json
    end

    def error_workflow_name
      object.error_workflow&.name
    end

    def include_error_workflow_name?
      object.error_workflow_id.present?
    end

    def last_execution_at
      return unless object.attributes.key?("last_execution_at")
      object.attributes["last_execution_at"]
    end

    def last_execution_status
      return unless object.attributes.key?("last_execution_status_value")
      DiscourseWorkflows::Execution.statuses.key(object.attributes["last_execution_status_value"])
    end

    def last_execution_node_outputs
      execution =
        object
          .executions
          .includes(:execution_data)
          .where(status: :success)
          .order(created_at: :desc)
          .first
      return unless execution&.execution_data

      entries = execution.execution_data.entries || {}
      outputs = {}
      entries.each do |node_id, steps|
        step = Array(steps).find { |s| s["status"] == "success" }
        next unless step
        items = step["output"] || []
        first_json = items.dig(0, "json")
        outputs[node_id] = first_json if first_json.present?
      end
      outputs
    end
  end
end
