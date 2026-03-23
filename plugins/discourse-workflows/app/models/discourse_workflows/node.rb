# frozen_string_literal: true

module DiscourseWorkflows
  class Node < ActiveRecord::Base
    self.table_name = "discourse_workflows_nodes"
    self.inheritance_column = nil

    include NodeTypeChecks

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

    validates :type, presence: true
    validates :name, presence: true
    validate :validate_configuration
    validate :validate_type_version

    private

    def validate_configuration
      return if type.blank?

      node_type = DiscourseWorkflows::Registry.find_node_type(type, version: type_version)
      return unless node_type.respond_to?(:validate_configuration)

      node_type.validate_configuration(configuration, errors)
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
