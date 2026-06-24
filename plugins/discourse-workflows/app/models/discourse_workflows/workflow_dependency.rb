# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowDependency < ActiveRecord::Base
    self.table_name = "discourse_workflows_workflow_dependencies"

    TOPIC_ADMIN_BUTTON_CACHE_KEY = "topic_admin_buttons"
    ACTIVE_NODE_TYPES_KEY = "active_node_types"
    USER_MODAL_CACHE_KEY = "has_user_modals"

    belongs_to :workflow, class_name: "DiscourseWorkflows::Workflow"
    belongs_to :workflow_version,
               class_name: "DiscourseWorkflows::WorkflowVersion",
               foreign_key: "workflow_version_id",
               primary_key: "version_id",
               optional: true

    TYPES = %w[credential_id data_table_id node_type workflow_call error_workflow].freeze

    validates :dependency_type, inclusion: { in: TYPES }

    scope :of_type, ->(type) { where(dependency_type: type) }

    def self.cache
      @cache ||= DistributedCache.new("discourse_workflows_dependencies")
    end

    def self.clear_cache!
      cache.clear
    end

    def self.cached_topic_admin_buttons
      cache.defer_get_set(TOPIC_ADMIN_BUTTON_CACHE_KEY) do
        Workflow::Action::FindPublishedTriggers
          .call(trigger_type: "trigger:topic_admin_button")
          .map do |published_trigger|
            {
              trigger_node_id: published_trigger.trigger_node_id,
              workflow_id: published_trigger.workflow_id,
              label: NodeData.parameters(published_trigger.trigger_node)["label"],
              icon: NodeData.parameters(published_trigger.trigger_node)["icon"],
            }
          end
      end
    end

    def self.active_node_types
      cache.defer_get_set(ACTIVE_NODE_TYPES_KEY) do
        of_type("node_type")
          .joins(:workflow)
          .where(
            "discourse_workflows_workflow_dependencies.workflow_version_id = " \
              "discourse_workflows_workflows.active_version_id",
          )
          .distinct
          .pluck(:dependency_key)
          .to_set
      end
    end

    def self.cached_user_modals?
      cache.defer_get_set(USER_MODAL_CACHE_KEY) do
        workflows_referencing("node_type", DiscourseWorkflows::Nodes::Modal::V1.identifier).exists?
      end
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
