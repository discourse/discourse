# frozen_string_literal: true

module DiscourseWorkflows
  module Forms
    module Schema
      HTML_SANITIZE_CONFIG = {
        elements: %w[
          a
          b
          br
          code
          div
          em
          h1
          h2
          h3
          h4
          h5
          h6
          i
          img
          li
          ol
          p
          pre
          source
          span
          strong
          sub
          sup
          table
          tbody
          td
          th
          thead
          tr
          u
          ul
          video
        ],
        attributes: {
          "a" => %w[href target title],
          "img" => %w[alt height src title width],
          "source" => %w[src type],
          "video" => %w[controls height poster src width],
        },
        protocols: {
          "a" => {
            "href" => %w[http https mailto],
          },
          "img" => {
            "src" => %w[http https],
          },
          "source" => {
            "src" => %w[http https],
          },
          "video" => {
            "poster" => %w[http https],
            "src" => %w[http https],
          },
        },
      }.freeze

      module_function

      def build(fields)
        form_fields = DiscourseWorkflows::Schemas::FormFields.with_keys(fields)

        {
          data: initial_data(form_fields),
          fields: form_fields.map { |field| field_schema(field) }.compact,
        }
      end

      def initial_data(fields)
        fields.each_with_object({}) do |field, data|
          next if field["field_type"] == "html"
          next if field["field_type"] == "hiddenField"

          data[field["key"]] = initial_value(field)
        end
      end

      def initial_value(field)
        default_value = field["default_value"]

        case field["field_type"]
        when "checkbox"
          ActiveModel::Type::Boolean.new.cast(default_value)
        when "password"
          ""
        else
          default_value.presence || ""
        end
      end

      def field_schema(field)
        type = field["field_type"].presence || "text"
        return if type == "hiddenField"

        schema = {
          name: field["key"],
          title: field["field_label"],
          description: field["description"],
          type: form_kit_type(type),
          validation: validation_for(field),
          placeholder: field["placeholder"],
          autofocus: false,
        }.compact

        case type
        when "dropdown", "radio"
          schema[:options] = options_for(field)
        when "html"
          schema[:html] = sanitize_html(field["html"])
        end

        schema
      end

      def form_kit_type(field_type)
        case field_type
        when "textarea"
          "textarea"
        when "checkbox"
          "checkbox"
        when "dropdown"
          "select"
        when "number"
          "input-number"
        when "email"
          "input-email"
        when "password"
          "password"
        when "date"
          "input-date"
        when "radio"
          "radio-group"
        when "html"
          "html"
        else
          "input"
        end
      end

      def validation_for(field)
        return if %w[checkbox hiddenField html].include?(field["field_type"])

        "required" if field["required"]
      end

      def options_for(field)
        options = field["options"]
        values = options.is_a?(Hash) ? options["values"] : options

        Array
          .wrap(values)
          .filter_map do |option|
            value = option.is_a?(Hash) ? option["value"] || option[:value] : option
            next if value.blank?

            { value: value, label: value }
          end
      end

      def sanitize_html(html)
        Sanitize.fragment(html.to_s, HTML_SANITIZE_CONFIG)
      end
    end
  end
end
