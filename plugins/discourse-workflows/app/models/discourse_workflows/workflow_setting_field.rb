# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSettingField < ActiveRecord::Base
    self.table_name = "discourse_workflows_workflow_setting_fields"

    FIELD_TYPES = %w[
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

    belongs_to :workflow, class_name: "DiscourseWorkflows::Workflow"

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
    validates :label, presence: true, length: { maximum: 255 }
    validates :description, length: { maximum: 500 }, allow_nil: true
    validates :field_type, presence: true, inclusion: { in: FIELD_TYPES }
    validate :enum_must_have_choices

    def definition
      {
        "key" => key,
        "label" => label,
        "description" => description,
        "type" => field_type,
        "type_options" => type_options || {},
      }
    end

    def to_version_entry
      definition.merge("value" => value)
    end

    def self.value_valid_for_type?(value:, field_type:, type_options:)
      value = value.to_s
      return true if value.blank?

      case field_type
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
      return unless field_type == "enum"
      return if type_options.is_a?(Hash) && Array(type_options["choices"]).present?

      errors.add(:type_options, :enum_choices_required)
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_workflow_setting_fields
#
#  id           :bigint           not null, primary key
#  description  :string(500)
#  field_type   :string(30)       not null
#  key          :string(100)      not null
#  label        :string(255)      not null
#  type_options :jsonb            not null
#  value        :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  workflow_id  :bigint           not null
#
# Indexes
#
#  idx_dwf_setting_fields_on_workflow_key  (workflow_id,key) UNIQUE
#
