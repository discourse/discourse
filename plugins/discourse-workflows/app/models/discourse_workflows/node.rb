# frozen_string_literal: true

module DiscourseWorkflows
  class Node < ActiveRecord::Base
    self.table_name = "discourse_workflows_nodes"
    self.inheritance_column = nil

    include NodeTypeChecks
    include TriggerTracking

    belongs_to :workflow, class_name: "DiscourseWorkflows::Workflow", foreign_key: "workflow_id"

    has_many :outgoing_connections,
             class_name: "DiscourseWorkflows::Connection",
             foreign_key: "source_node_id",
             dependent: :destroy
    has_many :incoming_connections,
             class_name: "DiscourseWorkflows::Connection",
             foreign_key: "target_node_id",
             dependent: :destroy

    scope :enabled_of_type,
          ->(type) do
            joins(:workflow).where(type: type).where(
              discourse_workflows_workflows: {
                enabled: true,
              },
            )
          end

    scope :enabled_triggers, ->(trigger_type) { enabled_of_type("trigger:#{trigger_type}") }

    before_validation :coerce_configuration_types

    validates :type, presence: true
    validates :name, presence: true
    validate :validate_configuration
    validate :validate_type_version

    def downstream_form?
      outgoing_connections
        .joins(:target_node)
        .where(discourse_workflows_nodes: { type: "action:form" })
        .exists?
    end

    def form_data_from(submitted_params)
      Array(configuration["form_fields"]).each_with_object({}) do |field, data|
        key = field["field_label"].to_s.parameterize(separator: "_")
        data[key] = coerce_field_value(submitted_params[key], field["field_type"])
      end
    end

    private

    def coerce_configuration_types
      return if type.blank? || configuration.blank?

      node_type = DiscourseWorkflows::Registry.find_node_type(type, version: type_version)
      return unless node_type.respond_to?(:configuration_schema)

      schema = node_type.configuration_schema
      return if schema.blank?

      coerced = configuration.dup
      schema.each do |key, field_schema|
        str_key = key.to_s
        next unless coerced.key?(str_key)

        value = coerced[str_key]
        next if value.nil?

        case field_schema[:type]
        when :integer
          coerced[str_key] = Integer(value) if !value.is_a?(Integer)
        when :number
          coerced[str_key] = Float(value) if !value.is_a?(Numeric)
        end
      rescue ArgumentError, TypeError
        next
      end

      self.configuration = coerced
    end

    def coerce_field_value(value, field_type)
      case field_type
      when "number"
        if value.present?
          value.to_s.include?(".") ? value.to_f : value.to_i
        end
      when "checkbox"
        ActiveModel::Type::Boolean.new.cast(value)
      else
        value
      end
    end

    def validate_configuration
      return if type.blank?

      node_type = DiscourseWorkflows::Registry.find_node_type(type, version: type_version)
      return unless node_type.respond_to?(:validate_configuration)

      node_errors = ActiveModel::Errors.new(self)
      node_type.validate_configuration(configuration, node_errors)
      node_errors.each { |error| errors.add(error.attribute, "#{name}: #{error.message}") }
    end

    def validate_type_version
      return if type.blank? || type_version.blank?

      available = DiscourseWorkflows::Registry.available_versions(type)
      return if available.empty?

      errors.add(:type_version, :inclusion) if available.exclude?(type_version)
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_nodes
#
#  id             :bigint           not null, primary key
#  configuration  :jsonb
#  name           :string           not null
#  position       :jsonb
#  position_index :integer          default(0), not null
#  static_data    :jsonb            not null
#  type           :string           not null
#  type_version   :string           default("1.0"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  workflow_id    :integer          not null
#
# Indexes
#
#  index_discourse_workflows_nodes_on_workflow_id  (workflow_id)
#
