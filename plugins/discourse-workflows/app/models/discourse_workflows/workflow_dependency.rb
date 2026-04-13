# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowDependency < ActiveRecord::Base
    self.table_name = "discourse_workflows_workflow_dependencies"

    belongs_to :workflow, class_name: "DiscourseWorkflows::Workflow"

    TYPES = %w[
      credential_id
      data_table_id
      node_type
      webhook_path
      workflow_call
      error_workflow
    ].freeze

    validates :dependency_type, inclusion: { in: TYPES }

    scope :of_type, ->(type) { where(dependency_type: type) }

    def self.workflows_referencing(type, key)
      where(dependency_type: type, dependency_key: key.to_s).select(:workflow_id)
    end

    def self.enabled_workflows_with_node_type(type)
      workflow_ids =
        joins(
          "INNER JOIN discourse_workflows_workflows ON discourse_workflows_workflows.id = discourse_workflows_workflow_dependencies.workflow_id",
        )
          .where(dependency_type: "node_type", dependency_key: type)
          .where("discourse_workflows_workflows.enabled = true")
          .pluck(:workflow_id)
          .uniq

      DiscourseWorkflows::Workflow
        .where(id: workflow_ids)
        .flat_map { |workflow| workflow.nodes_of_type(type).map { |node| [workflow, node] } }
    end

    def self.enabled_trigger_entries(trigger_type)
      joins(
        "INNER JOIN discourse_workflows_workflows ON discourse_workflows_workflows.id = discourse_workflows_workflow_dependencies.workflow_id",
      )
        .where(dependency_type: "node_type", dependency_key: trigger_type)
        .where("discourse_workflows_workflows.enabled = true")
        .pluck(:workflow_id, :node_id)
        .map { |workflow_id, node_id| { workflow_id: workflow_id, node_id: node_id } }
    end
  end
end
