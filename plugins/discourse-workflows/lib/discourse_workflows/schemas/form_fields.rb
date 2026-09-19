# frozen_string_literal: true

module DiscourseWorkflows
  module Schemas
    module FormFields
      MAX_FIELD_VALUE_LENGTH = 10_000
      EMAIL_REGEX = URI::MailTo::EMAIL_REGEXP

      ValidationResult =
        Struct.new(:errors, :data, keyword_init: true) do
          def valid?
            errors.empty?
          end
        end

      ValidationError = Struct.new(:field_label, :code, keyword_init: true)

      ITEM_SCHEMA = {
        field_label: {
          type: :string,
          required: true,
        },
        field_type: {
          type: :options,
          required: true,
          default: "text",
          options: %w[
            text
            textarea
            number
            email
            password
            date
            checkbox
            dropdown
            radio
            hiddenField
            html
          ],
          ui: {
            expression: true,
          },
        },
      }.freeze

      EXTRA_ITEM_SCHEMA = {
        field_name: {
          type: :string,
        },
        required: {
          type: :boolean,
          default: false,
          display_options: {
            hide: {
              field_type: %w[hiddenField html],
            },
          },
        },
        description: {
          type: :string,
        },
        placeholder: {
          type: :string,
          display_options: {
            show: {
              field_type: %w[text textarea number email password],
            },
          },
        },
        default_value: {
          type: :string,
          display_options: {
            hide: {
              field_type: %w[password hiddenField html],
            },
          },
        },
        options: {
          type: :fixed_collection,
          display_options: {
            show: {
              field_type: %w[dropdown radio],
            },
          },
          type_options: {
            multiple_values: true,
          },
          options: [
            {
              name: "values",
              values: {
                value: {
                  type: :string,
                  required: true,
                  ui: {
                    show_label: false,
                  },
                },
              },
            },
          ],
        },
        field_value: {
          type: :string,
          display_options: {
            show: {
              field_type: %w[hiddenField],
            },
          },
        },
        html: {
          type: :string,
          display_options: {
            show: {
              field_type: %w[html],
            },
          },
          ui: {
            control: :textarea,
          },
        },
      }.freeze

      SCHEMA = {
        type: :fixed_collection,
        required: true,
        type_options: {
          multiple_values: true,
          hide_optional_fields: true,
        },
        options: [{ name: "values", values: ITEM_SCHEMA.merge(EXTRA_ITEM_SCHEMA) }],
      }.freeze

      module_function

      def field_key(field)
        field["field_name"].presence || field["field_label"].to_s.parameterize(separator: "_")
      end

      def with_keys(fields)
        Array.wrap(fields).map { |field| field.merge("key" => field_key(field)) }
      end

      def apply_query_defaults(fields, query_parameters)
        normalized_query_parameters = (query_parameters || {}).to_h.with_indifferent_access

        fields.map do |field|
          key = field["key"] || field_key(field)
          next field unless normalized_query_parameters.key?(key)

          case field["field_type"]
          when "hiddenField"
            next field if field["field_value"].present?

            field.merge("field_value" => normalized_query_parameters[key])
          when "password", "html"
            field
          else
            field.merge("default_value" => normalized_query_parameters[key])
          end
        end
      end

      def public_fields(fields)
        fields.map do |field|
          case field["field_type"]
          when "hiddenField"
            field.except("field_value", "default_value")
          when "password"
            field.except("default_value")
          else
            field
          end
        end
      end

      def validate_submission(fields, submitted_params, query_parameters: nil)
        submitted = (submitted_params || {}).with_indifferent_access
        query_parameters = (query_parameters || {}).to_h.with_indifferent_access
        errors = []
        data = {}

        with_keys(fields).each do |field|
          next if field["field_type"] == "html"

          key = field["key"]

          if field["field_type"] == "hiddenField"
            data[key] = hidden_value(field, query_parameters)
            next
          end

          value = submitted[key]

          if missing?(field, value)
            errors << build_error(field, :missing)
            next
          end

          begin
            coerced_value = coerce(value, field["field_type"])
            if valid_value?(coerced_value, field)
              data[key] = coerced_value
            else
              errors << build_error(field, :invalid_value)
            end
          rescue ArgumentError, TypeError
            errors << build_error(field, :invalid_value)
          end
        end

        ValidationResult.new(errors: errors, data: data)
      end

      def missing?(field, value)
        return false unless field["required"]
        return false if field["field_type"] == "checkbox"
        return false if field["field_type"] == "hiddenField"
        return false if field["field_type"] == "html"

        value.blank?
      end

      def hidden_value(field, query_parameters)
        value = field["field_value"].presence || query_parameters[field["key"]]

        coerce(value.presence || "", "hiddenField")
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

      def valid_value?(value, field)
        return true if value.blank?
        return true unless field["field_type"] == "email"

        EMAIL_REGEX.match?(value)
      end

      def build_error(field, code)
        ValidationError.new(field_label: field["field_label"], code: code)
      end
    end
  end
end
