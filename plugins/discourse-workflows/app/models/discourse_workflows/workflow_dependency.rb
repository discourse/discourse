# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowDependency < ActiveRecord::Base
    self.table_name = "discourse_workflows_workflow_dependencies"

    CACHE_KEY = "topic_admin_buttons"

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

    def self.cache
      @cache ||= DistributedCache.new("discourse_workflows_dependencies")
    end

    def self.clear_cache!
      cache.clear
    end

    def self.cached_topic_admin_buttons
      cache.defer_get_set(CACHE_KEY) do
        enabled_workflows_with_node_type("trigger:topic_admin_button").map do |workflow, node|
          {
            trigger_node_id: node["id"],
            workflow_id: workflow.id,
            label: node.dig("configuration", "label"),
            icon: node.dig("configuration", "icon"),
          }
        end
      end
    end

    def self.workflows_referencing(type, key)
      where(dependency_type: type, dependency_key: key.to_s).select(:workflow_id)
    end

    def self.enabled_workflows_with_node_type(type)
      pairs =
        joins(:workflow).where(
          dependency_type: "node_type",
          dependency_key: type,
          workflows: {
            enabled: true,
          },
        ).pluck(:workflow_id, :node_id)

      return [] if pairs.empty?

      workflows_by_id =
        DiscourseWorkflows::Workflow.where(id: pairs.map(&:first).uniq).index_by(&:id)

      pairs.filter_map do |workflow_id, node_id|
        workflow = workflows_by_id[workflow_id]
        node = workflow&.find_node(node_id)
        [workflow, node] if workflow && node
      end
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
