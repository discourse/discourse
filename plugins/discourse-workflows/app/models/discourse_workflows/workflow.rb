# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow < ActiveRecord::Base
    self.table_name = "discourse_workflows_workflows"
    self.ignored_columns = %w[sticky_notes allowed_group_ids]

    has_many :executions,
             class_name: "DiscourseWorkflows::Execution",
             foreign_key: "workflow_id",
             dependent: :destroy

    has_many :workflow_dependencies,
             class_name: "DiscourseWorkflows::WorkflowDependency",
             foreign_key: "workflow_id",
             dependent: :delete_all

    belongs_to :created_by, class_name: "User", foreign_key: "created_by_id"
    belongs_to :updated_by, class_name: "User", foreign_key: "updated_by_id", optional: true
    belongs_to :error_workflow,
               class_name: "DiscourseWorkflows::Workflow",
               foreign_key: "error_workflow_id",
               optional: true

    attribute :nodes, default: -> { [] }
    attribute :connections, default: -> { [] }
    attribute :static_data, default: -> { {} }

    validates :name, presence: true, length: { maximum: 100 }
    validate :error_workflow_must_exist

    scope :enabled, -> { where(enabled: true) }
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

    def nodes_of_type(type)
      parsed_nodes.select { |n| n["type"] == type }
    end

    def find_node(node_id)
      node_id_str = node_id.to_s
      parsed_nodes.find { |n| n["id"] == node_id_str }
    end

    def trigger_node
      parsed_nodes.find { |n| n["type"]&.start_with?("trigger:") }
    end

    def parsed_nodes
      nodes
    end

    def parsed_connections
      connections
    end

    def node_static_data(node_id)
      static_data.fetch(node_id.to_s, {})
    end

    def update_node_static_data!(node_id, data)
      update!(static_data: static_data.merge(node_id.to_s => data))
    end

    def each_seconds_schedule_rule
      parsed_nodes.each do |node|
        next unless node["type"] == "trigger:schedule"

        rules = ScheduleRule.rules_from_configuration(node["configuration"] || {})
        rules.each_with_index do |rule, rule_index|
          next unless ScheduleRule.seconds_rule?(rule)
          yield node, rule, rule_index
        end
      end
    end

    def connections_from_node(node_id)
      node_id_str = node_id.to_s
      parsed_connections.select { |c| c["source_node_id"] == node_id_str }
    end

    def node_has_reachable_downstream_of_type?(node_id, type)
      node_by_id = parsed_nodes.index_by { |n| n["id"] }
      visited = Set.new
      queue = [node_id.to_s]

      while (current = queue.shift)
        next if visited.include?(current)
        visited << current

        connections_from_node(current).each do |conn|
          target_id = conn["target_node_id"]
          target_node = node_by_id[target_id]
          next unless target_node
          return true if target_node["type"] == type
          queue << target_id
        end
      end

      false
    end

    def self.form_field_key(field)
      field["field_name"].presence || field["field_label"].to_s.parameterize(separator: "_")
    end

    def self.resolve_field_keys(fields)
      fields.map { |f| f.merge("key" => form_field_key(f)) }
    end

    def self.missing_required_form_fields(node, submitted_params)
      data = submitted_params.with_indifferent_access
      Array(node.dig("configuration", "form_fields")).filter_map do |field|
        next unless field["required"]
        next if field["field_type"] == "checkbox"
        field["field_label"] if data[form_field_key(field)].blank?
      end
    end

    def self.form_data_from(node, submitted_params)
      Array(node.dig("configuration", "form_fields")).each_with_object({}) do |field, data|
        key = form_field_key(field)
        data[key] = coerce_form_field_value(submitted_params[key], field["field_type"])
      end
    end

    def self.coerce_form_field_value(value, field_type)
      case field_type
      when "number"
        return if value.blank?
        value.to_s.include?(".") ? Float(value) : Integer(value)
      when "checkbox"
        ActiveModel::Type::Boolean.new.cast(value)
      else
        value
      end
    end

    private

    def error_workflow_must_exist
      return if error_workflow_id.nil?
      if error_workflow_id == id || !Workflow.exists?(error_workflow_id)
        errors.add(:error_workflow_id, :invalid)
      end
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_workflows
#
#  id                :bigint           not null, primary key
#  allowed_group_ids :integer          default([]), is an Array
#  connections       :jsonb
#  enabled           :boolean          default(FALSE), not null
#  name              :string           not null
#  nodes             :jsonb
#  run_as_username   :string           default("system")
#  settings          :jsonb
#  static_data       :jsonb
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  created_by_id     :integer          not null
#  error_workflow_id :integer
#  updated_by_id     :integer
#
# Indexes
#
#  idx_workflows_nodes_gin                                   (nodes) USING gin
#  index_discourse_workflows_workflows_on_created_by_id      (created_by_id)
#  index_discourse_workflows_workflows_on_error_workflow_id  (error_workflow_id)
#  index_discourse_workflows_workflows_on_updated_by_id      (updated_by_id)
#
