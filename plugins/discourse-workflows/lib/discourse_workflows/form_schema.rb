# frozen_string_literal: true

module DiscourseWorkflows
  class FormSchema
    MAX_FIELD_VALUE_LENGTH = 10_000

    Result =
      Struct.new(:errors, :data, keyword_init: true) do
        def valid?
          errors.empty?
        end
      end

    Error = Struct.new(:field_label, :code, keyword_init: true)

    def self.validate(node, submitted_params)
      new(node, submitted_params).validate
    end

    def initialize(node, submitted_params)
      @fields = Array(node.dig("configuration", "form_fields"))
      @submitted = (submitted_params || {}).with_indifferent_access
    end

    def validate
      errors = []
      data = {}

      @fields.each do |field|
        key = Workflow.form_field_key(field)
        value = @submitted[key]

        if missing?(field, value)
          errors << build_error(field, :missing)
          next
        end

        begin
          data[key] = coerce(value, field["field_type"])
        rescue ArgumentError, TypeError
          errors << build_error(field, :invalid_value)
        end
      end

      Result.new(errors: errors, data: data)
    end

    private

    def missing?(field, value)
      return false unless field["required"]
      return false if field["field_type"] == "checkbox"
      value.blank?
    end

    def coerce(value, field_type)
      case field_type
      when "number"
        return if value.blank?
        value.to_s.include?(".") ? Float(value) : Integer(value)
      when "checkbox"
        ActiveModel::Type::Boolean.new.cast(value)
      else
        value.is_a?(String) ? value.truncate(MAX_FIELD_VALUE_LENGTH) : value
      end
    end

    def build_error(field, code)
      Error.new(field_label: field["field_label"], code: code)
    end
  end
end
