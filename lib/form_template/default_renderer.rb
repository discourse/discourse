# frozen_string_literal: true

class FormTemplate::DefaultRenderer
  def self.render(field_values)
    field_values
      .fields
      .filter_map do |field|
        value = field_values.answers[field["id"]]
        next if value.blank? && value != true

        text =
          case value
          when true
            "on"
          when Array
            value.join("\n")
          else
            value
          end

        label = field.dig("attributes", "label") || field["id"]
        "### #{label}\n#{text}"
      end
      .join("\n\n")
  end
end
