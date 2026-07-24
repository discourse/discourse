# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :nodes,
               :connections,
               :version_id,
               :active_version_id,
               :version_counter,
               :has_unpublished_changes,
               :error_workflow_id,
               :error_workflow_name,
               :settings,
               :static_data,
               :timezone,
               :created_at,
               :updated_at,
               :last_execution_status,
               :last_execution_at,
               :last_execution_run_data,
               :pin_data

    attribute :created_by
    attribute :updated_by

    def id
      object.id.to_s
    end

    def nodes
      object.nodes || []
    end

    def connections
      object.connections || {}
    end

    def version_id
      object.version_id
    end

    def active_version_id
      object.active_version_id
    end

    def version_counter
      object.version_counter
    end

    def has_unpublished_changes
      object.has_unpublished_changes?
    end

    def error_workflow_id
      object.error_workflow_id
    end

    def settings
      object.settings || {}
    end

    def static_data
      object.normalized_static_data
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

    def timezone
      object.settings&.dig("timezone") || DiscourseWorkflows::WorkflowTimezone.default
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

    def include_last_execution_run_data?
      !object.attributes.key?("last_execution_status_value")
    end

    def last_execution_run_data
      execution =
        object
          .executions
          .includes(:execution_data)
          .where(status: :success)
          .order(created_at: :desc)
          .first
      execution&.execution_data&.run_data
    end

    def pin_data
      object.pin_data || {}
    end

    def include_pin_data?
      !object.attributes.key?("last_execution_status_value")
    end
  end
end
