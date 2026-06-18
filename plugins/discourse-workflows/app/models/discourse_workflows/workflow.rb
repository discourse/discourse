# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow < ActiveRecord::Base
    self.table_name = "discourse_workflows_workflows"

    PUBLISH_EVENT_ACTIVATED = "activated"
    PUBLISH_EVENT_DEACTIVATED = "deactivated"

    has_many :executions,
             class_name: "DiscourseWorkflows::Execution",
             foreign_key: "workflow_id",
             dependent: :destroy

    has_many :workflow_dependencies,
             class_name: "DiscourseWorkflows::WorkflowDependency",
             foreign_key: "workflow_id",
             dependent: :delete_all
    has_many :webhooks,
             class_name: "DiscourseWorkflows::Webhook",
             foreign_key: "workflow_id",
             dependent: :delete_all
    has_many :workflow_versions,
             class_name: "DiscourseWorkflows::WorkflowVersion",
             foreign_key: "workflow_id",
             dependent: :delete_all
    has_many :publish_history,
             -> { order(created_at: :desc) },
             class_name: "DiscourseWorkflows::WorkflowPublishHistory",
             foreign_key: "workflow_id",
             dependent: :delete_all
    has_many :ai_authoring_sessions,
             class_name: "DiscourseWorkflows::AiAuthoringSession",
             foreign_key: "workflow_id",
             dependent: :delete_all
    has_many :workflow_call_runs,
             class_name: "DiscourseWorkflows::WorkflowCallRun",
             foreign_key: "target_workflow_id",
             dependent: :delete_all

    belongs_to :created_by, class_name: "User", foreign_key: "created_by_id"
    belongs_to :updated_by, class_name: "User", foreign_key: "updated_by_id", optional: true
    belongs_to :active_version,
               class_name: "DiscourseWorkflows::WorkflowVersion",
               foreign_key: "active_version_id",
               primary_key: "version_id",
               optional: true
    belongs_to :error_workflow,
               class_name: "DiscourseWorkflows::Workflow",
               foreign_key: "error_workflow_id",
               optional: true

    before_validation :assign_version_id, on: :create

    STATIC_DATA_GLOBAL_KEY = "global"
    STATIC_DATA_NODE_PREFIX = "node:"
    EMPTY_STATIC_DATA = {}.freeze

    attribute :nodes, default: -> { [] }
    attribute :connections, default: -> { {} }
    attribute :static_data, default: -> { Marshal.load(Marshal.dump(EMPTY_STATIC_DATA)) }
    attribute :trigger_state, default: -> { {} }
    attribute :settings, default: -> { {} }
    attribute :pin_data, default: -> { {} }

    validates :name, presence: true, length: { maximum: 100 }
    validates :version_id, presence: true, length: { maximum: 36 }
    validate :error_workflow_must_exist
    validate :error_workflow_cannot_be_self

    before_destroy :nullify_error_workflow_back_references

    scope :published, -> { where.not(active_version_id: nil) }
    scope :filter_by_name,
          ->(name) do
            where("discourse_workflows_workflows.name ILIKE ?", "%#{sanitize_sql_like(name)}%")
          end
    scope :filter_by_trigger_type,
          ->(type) do
            where(
              "discourse_workflows_workflows.nodes @> ?",
              [{ "type" => "trigger:#{type}" }].to_json,
            )
          end

    def self.filtered(name: nil, trigger_type: nil, exclude_id: nil)
      scope = all
      scope = scope.filter_by_name(name) if name.present?
      scope = scope.filter_by_trigger_type(trigger_type) if trigger_type.present?
      scope = scope.where.not(id: exclude_id) if exclude_id
      scope
    end

    def find_node(node_id)
      find_node_in(nodes, node_id)
    end

    def find_published_node(node_id)
      find_node_in(published_nodes, node_id)
    end

    def published_nodes
      active_version&.nodes || []
    end

    def published_connections
      active_version&.connections || {}
    end

    def snapshot!(user:, autosaved: false, authors: nil)
      new_version_id = SecureRandom.uuid
      new_counter = version_counter.to_i + 1

      update!(version_id: new_version_id, version_counter: new_counter, updated_by: user)

      workflow_versions.create!(
        version_id: new_version_id,
        version_number: new_counter,
        name: name,
        nodes: nodes,
        connections: connections,
        settings: settings || {},
        autosaved: autosaved,
        authors: authors,
        created_by: user,
        updated_by: user,
      )
    end

    def initial_snapshot!(user:, authors: nil)
      workflow_versions.create!(
        version_id: version_id,
        version_number: version_counter,
        name: name,
        nodes: nodes,
        connections: connections,
        settings: settings || {},
        autosaved: false,
        authors: authors,
        created_by: user,
        updated_by: user,
      )
    end

    def publish!(user: nil)
      published_node_ids = active_version_target&.nodes&.map { |n| n["id"].to_s } || []

      transaction do
        update!(
          active_version_id: version_id,
          trigger_state: (trigger_state || {}).slice(*published_node_ids),
        )
        publish_history.create!(
          version_id: version_id,
          event: PUBLISH_EVENT_ACTIVATED,
          user_id: user&.id,
        )
      end
    end

    def unpublish!(user: nil)
      previous_active_version_id = active_version_id

      transaction do
        update!(active_version_id: nil)
        publish_history.create!(
          version_id: previous_active_version_id,
          event: PUBLISH_EVENT_DEACTIVATED,
          user_id: user&.id,
        )
      end
    end

    def restore_from_version!(version, user:)
      update!(
        name: version.name,
        nodes: version.nodes || [],
        connections: version.connections || {},
        settings: version.settings || {},
        version_id: version.version_id,
        updated_by: user,
      )
    end

    def published?
      active_version_id.present?
    end

    def callable_as_subworkflow?
      published? && Nodes::WorkflowCallTrigger::V1.find_in(active_version&.nodes).present?
    end

    def has_unpublished_changes?
      published? && version_id != active_version_id
    end

    def versioned_payload
      JSON.parse(
        {
          name: name,
          nodes: nodes || [],
          connections: connections || {},
          settings: settings || {},
        }.to_json,
      )
    end

    def find_node_in(node_collection, node_id)
      node_id_str = node_id.to_s
      node_collection.find { |n| n["id"] == node_id_str }
    end

    def trigger_node
      nodes.find { |n| n["type"]&.start_with?("trigger:") }
    end

    def normalized_static_data
      static_data.presence || {}
    end

    def global_static_data
      self.class.static_data_slot(normalized_static_data[STATIC_DATA_GLOBAL_KEY])
    end

    def node_static_data(node_name)
      self.class.static_data_slot(normalized_static_data[static_data_node_key(node_name)])
    end

    def node_static_data_entries
      normalized_static_data.each_with_object({}) do |(key, value), entries|
        key = key.to_s
        next unless key.start_with?(STATIC_DATA_NODE_PREFIX)

        entries[key.delete_prefix(STATIC_DATA_NODE_PREFIX)] = self.class.static_data_slot(value)
      end
    end

    def update_global_static_data!(data)
      next_data = normalized_static_data
      next_data[STATIC_DATA_GLOBAL_KEY] = self.class.static_data_slot(data)
      update!(static_data: next_data)
    end

    def update_node_static_data!(node_name, data)
      next_data = normalized_static_data
      next_data[static_data_node_key(node_name)] = self.class.static_data_slot(data)
      update!(static_data: next_data)
    end

    def commit_static_data!(global:, node:)
      current_data = normalized_static_data
      next_data =
        current_data.reject do |key, _|
          key = key.to_s
          key == STATIC_DATA_GLOBAL_KEY || key.start_with?(STATIC_DATA_NODE_PREFIX)
        end

      if global.present? || current_data.key?(STATIC_DATA_GLOBAL_KEY)
        next_data[STATIC_DATA_GLOBAL_KEY] = self.class.static_data_slot(global)
      end

      (node || {}).each do |node_name, data|
        next_data[static_data_node_key(node_name)] = self.class.static_data_slot(data)
      end

      update!(static_data: next_data)
    end

    def static_data_node_key(node_name)
      self.class.static_data_node_key(node_name)
    end

    def self.static_data_node_key(node_name)
      "#{STATIC_DATA_NODE_PREFIX}#{node_name}"
    end

    def self.static_data_slot(value)
      value.is_a?(Hash) ? value : {}
    end

    def self.valid_static_data_map?(value)
      value.is_a?(Hash) &&
        value.all? { |key, slot| key.to_s != "node" && static_data_slot(slot) == slot }
    end

    def node_trigger_state(node_id)
      (trigger_state || {}).fetch(node_id.to_s, {})
    end

    def update_node_trigger_state!(node_id, data)
      update!(trigger_state: (trigger_state || {}).merge(node_id.to_s => data))
    end

    def node_pin_data(node_name)
      pin_data&.fetch(node_name.to_s, nil)
    end

    def node_pinned?(node_name)
      node_pin_data(node_name).present?
    end

    def update_node_pin_data!(node_name, items)
      key = node_name.to_s
      next_pin_data = (pin_data || {}).dup
      if items.nil?
        next_pin_data.delete(key)
      else
        next_pin_data[key] = items
      end
      update!(pin_data: next_pin_data)
    end

    def pinned_node_names
      (pin_data || {}).keys
    end

    def last_successful_execution
      executions.successful.includes(:execution_data).order(created_at: :desc).first
    end

    def node_has_reachable_downstream_of_type?(node_id, type, published: false)
      graph_nodes = published ? published_nodes : nodes
      graph_connections = published ? published_connections : connections
      DiscourseWorkflows::WorkflowSnapshot.new(
        "name" => name,
        "nodes" => graph_nodes,
        "connections" => graph_connections,
      ).node_has_reachable_downstream_of_type?(node_id, type)
    end

    private

    def assign_version_id
      self.version_id ||= SecureRandom.uuid
    end

    def active_version_target
      workflow_versions.find_by(version_id: version_id) || active_version
    end

    def error_workflow_must_exist
      return if error_workflow_id.nil?
      errors.add(:error_workflow_id, :invalid) unless Workflow.exists?(error_workflow_id)
    end

    def error_workflow_cannot_be_self
      return if error_workflow_id.nil? || id.nil?
      errors.add(:error_workflow_id, :cannot_be_self) if error_workflow_id == id
    end

    def nullify_error_workflow_back_references
      Workflow.where(error_workflow_id: id).update_all(
        error_workflow_id: nil,
        updated_at: Time.current,
      )
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_workflows
#
#  id                :bigint           not null, primary key
#  connections       :jsonb            not null
#  name              :string(100)      not null
#  nodes             :jsonb            not null
#  pin_data          :jsonb            not null
#  settings          :jsonb            not null
#  static_data       :jsonb            not null
#  trigger_state     :jsonb            not null
#  version_counter   :integer          default(1), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  active_version_id :string(36)
#  created_by_id     :integer          not null
#  error_workflow_id :bigint
#  updated_by_id     :integer
#  version_id        :string(36)       not null
#
# Indexes
#
#  idx_dwf_workflows_on_active_version_id  (active_version_id)
#  idx_dwf_workflows_on_created_by_id      (created_by_id)
#  idx_dwf_workflows_on_error_workflow_id  (error_workflow_id)
#  idx_dwf_workflows_on_updated_by_id      (updated_by_id)
#  idx_dwf_workflows_on_version_id         (version_id) UNIQUE
#
