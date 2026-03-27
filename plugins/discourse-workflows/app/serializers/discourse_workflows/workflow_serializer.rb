# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :enabled,
               :sticky_notes,
               :error_workflow_id,
               :created_at,
               :updated_at,
               :last_execution_status,
               :last_execution_at

    has_many :nodes, serializer: DiscourseWorkflows::NodeSerializer, embed: :objects
    has_many :connections, serializer: DiscourseWorkflows::ConnectionSerializer, embed: :objects

    attribute :created_by
    attribute :updated_by

    def created_by
      BasicUserSerializer.new(object.created_by, root: false).as_json
    end

    def updated_by
      return if object.updated_by.blank?

      BasicUserSerializer.new(object.updated_by, root: false).as_json
    end

    def last_execution_at
      return unless object.attributes.key?("last_execution_at")

      object.attributes["last_execution_at"]
    end

    def last_execution_status
      return unless object.attributes.key?("last_execution_status_value")

      DiscourseWorkflows::Execution.statuses.key(object.attributes["last_execution_status_value"])
    end

    def nodes
      object.nodes.sort_by(&:position_index)
    end
  end
end
