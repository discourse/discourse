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
  end
end
