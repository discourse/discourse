# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowDependency < ActiveRecord::Base
    self.table_name = "discourse_workflows_workflow_dependencies"

    DEPENDENCY_INDEX_CACHE_KEY = "dependency_index"

    belongs_to :workflow, class_name: "DiscourseWorkflows::Workflow"
    belongs_to :workflow_version,
               class_name: "DiscourseWorkflows::WorkflowVersion",
               foreign_key: "workflow_version_id",
               primary_key: "version_id",
               optional: true

    TYPES = %w[credential_id data_table_id node_type workflow_call error_workflow].freeze

    validates :dependency_type, inclusion: { in: TYPES }

    scope :of_type, ->(type) { where(dependency_type: type) }
    scope :on_active_version,
          -> do
            joins(:workflow).where(
              "discourse_workflows_workflow_dependencies.workflow_version_id = " \
                "discourse_workflows_workflows.active_version_id",
            )
          end

    def self.cache
      @cache ||= DistributedCache.new("discourse_workflows_dependencies")
    end

    def self.clear_cache!
      cache.clear
    end

    def self.cached_topic_admin_buttons
      cached_published_triggers("trigger:topic_admin_button").map do |published_trigger|
        {
          trigger_node_id: published_trigger.trigger_node_id,
          workflow_id: published_trigger.workflow_id,
          label: NodeData.parameters(published_trigger.trigger_node)["label"],
          icon: NodeData.parameters(published_trigger.trigger_node)["icon"],
        }
      end
    end

    def self.active_node_types
      cached_dependency_index[:active_node_types].to_set
    end

    def self.cached_published_triggers(trigger_type)
      Array(
        cached_dependency_index[:published_triggers_by_type][trigger_type],
      ).map do |published_trigger|
        DiscourseWorkflows::CachedPublishedTrigger.from_hash(published_trigger)
      end
    end

    def self.cached_user_modals?
      cached_dependency_index[:referenced_node_types].include?(
        DiscourseWorkflows::Nodes::Modal::V1.identifier,
      )
    end

    def self.workflows_referencing(type, key)
      joins(:workflow)
        .where(dependency_type: type, dependency_key: key.to_s)
        .where(
          "discourse_workflows_workflow_dependencies.workflow_version_id IN " \
            "(discourse_workflows_workflows.version_id, " \
            "discourse_workflows_workflows.active_version_id)",
        )
        .select(:workflow_id)
    end

    def self.cached_dependency_index
      cache.defer_get_set(DEPENDENCY_INDEX_CACHE_KEY) do
        rows = active_node_type_rows
        versions_by_id =
          WorkflowVersion.where(
            version_id: rows.map { |row| row[:workflow_version_id] }.uniq,
          ).index_by(&:version_id)

        {
          active_node_types: rows.map { |row| row[:node_type] }.uniq,
          referenced_node_types: referenced_node_types,
          published_triggers_by_type: published_triggers_by_type(rows, versions_by_id),
        }
      end
    end

    def self.active_node_type_rows
      of_type("node_type")
        .on_active_version
        .pluck(:dependency_key, :workflow_id, :workflow_version_id, :node_id)
        .map do |node_type, workflow_id, workflow_version_id, node_id|
          {
            node_type: node_type,
            workflow_id: workflow_id,
            workflow_version_id: workflow_version_id,
            node_id: node_id,
          }
        end
    end

    def self.referenced_node_types
      of_type("node_type")
        .joins(:workflow)
        .where(
          "discourse_workflows_workflow_dependencies.workflow_version_id IN " \
            "(discourse_workflows_workflows.version_id, " \
            "discourse_workflows_workflows.active_version_id)",
        )
        .distinct
        .pluck(:dependency_key)
    end

    def self.published_triggers_by_type(rows, versions_by_id)
      rows.each_with_object({}) do |row, published_triggers|
        node_type = row[:node_type]
        next if !node_type.start_with?("trigger:")

        trigger_node =
          versions_by_id[row[:workflow_version_id]]&.nodes&.find do |candidate|
            candidate["id"] == row[:node_id].to_s
          end
        next unless trigger_node&.dig("type") == node_type

        cached_trigger =
          DiscourseWorkflows::CachedPublishedTrigger.new(
            workflow_id: row[:workflow_id],
            workflow_version_id: row[:workflow_version_id],
            trigger_node: trigger_node.deep_dup,
          )

        published_triggers[node_type] ||= []
        published_triggers[node_type] << cached_trigger.to_h
      end
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_workflow_dependencies
#
#  id                  :bigint           not null, primary key
#  dependency_key      :string(500)      not null
#  dependency_type     :string(50)       not null
#  created_at          :datetime         not null
#  node_id             :string(100)
#  workflow_id         :bigint           not null
#  workflow_version_id :string(36)
#
# Indexes
#
#  idx_dwf_deps_on_type_key             (dependency_type,dependency_key)
#  idx_dwf_deps_on_workflow_id          (workflow_id)
#  idx_dwf_deps_on_workflow_version_id  (workflow_version_id)
#
