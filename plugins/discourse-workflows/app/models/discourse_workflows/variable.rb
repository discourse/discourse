# frozen_string_literal: true

module DiscourseWorkflows
  class Variable < ActiveRecord::Base
    self.table_name = "discourse_workflows_variables"

    VARIABLE_TYPES = %w[
      string
      integer
      boolean
      enum
      category
      category_list
      group
      group_list
      tag_list
      simple_list
    ]

    belongs_to :created_by, class_name: "User", foreign_key: "created_by_id"
    belongs_to :workflow, class_name: "DiscourseWorkflows::Workflow", optional: true

    attribute :type_options, default: -> { {} }

    validates :key,
              presence: true,
              uniqueness: {
                scope: :workflow_id,
              },
              length: {
                maximum: 100,
              },
              format: {
                with: /\A[a-zA-Z_][a-zA-Z0-9_]*\z/,
              }
    validates :value, length: { maximum: 10_000 }
    validates :description, length: { maximum: 500 }, allow_nil: true
    validates :variable_type, presence: true, inclusion: { in: VARIABLE_TYPES }
    validate :enum_must_have_choices

    def label
      key.to_s.tr("_", " ").sub(/\A./, &:upcase)
    end

    def definition
      {
        "key" => key,
        "description" => description,
        "type" => variable_type,
        "type_options" => type_options || {},
      }
    end

    def to_version_entry
      definition.merge("value" => value)
    end

    def self.value_valid_for_type?(value:, variable_type:, type_options:)
      value = value.to_s
      return true if value.blank?

      case variable_type
      when "integer"
        value.match?(/\A-?\d+\z/)
      when "boolean"
        %w[true false].include?(value)
      when "enum"
        Array(type_options["choices"]).include?(value)
      when "category"
        ids_exist?(::Category, [value])
      when "category_list"
        ids_exist?(::Category, value.split("|"))
      when "group"
        ids_exist?(::Group, [value])
      when "group_list"
        ids_exist?(::Group, value.split("|"))
      when "tag_list"
        names_exist?(value.split("|"))
      else
        true
      end
    end

    def self.ids_exist?(klass, raw_ids)
      return false if raw_ids.empty?

      parsed_ids = raw_ids.map { |id| Integer(id, exception: false) }
      return false if parsed_ids.include?(nil)

      klass.where(id: parsed_ids).count == parsed_ids.size
    end
    private_class_method :ids_exist?

    def self.names_exist?(names)
      return false if names.empty?

      ::Tag.where(name: names).count == names.size
    end
    private_class_method :names_exist?

    private

    def enum_must_have_choices
      return unless variable_type == "enum"
      return if type_options.is_a?(Hash) && Array(type_options["choices"]).present?

      errors.add(:type_options, :enum_choices_required)
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_variables
#
#  id            :bigint           not null, primary key
#  description   :text
#  key           :string(100)      not null
#  type_options  :jsonb            not null
#  value         :text
#  variable_type :string(30)       default("string"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :integer          not null
#  workflow_id   :bigint
#
# Indexes
#
#  idx_dwf_variables_on_created_by_id  (created_by_id)
#  idx_dwf_variables_on_key_global     (key) UNIQUE WHERE (workflow_id IS NULL)
#  idx_dwf_variables_on_workflow_key   (workflow_id,key) UNIQUE WHERE (workflow_id IS NOT NULL)
#
