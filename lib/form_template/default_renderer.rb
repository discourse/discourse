# frozen_string_literal: true

class FormTemplate::DefaultRenderer
  def self.render(field_values)
    field_values
      .fields
      .filter_map do |field|
        value = field_values.answers[field["id"]]
        next if value.nil? || value == false || value == []

        text =
          case value
          when true
            "on"
          when Array
            value.join("\n")
          else
            value
          end

        # Empty successful controls leave a separator in the existing browser formatter.
        next "" if text.empty?

        label = field.fetch("attributes", {}).fetch("label", "undefined")
        label = "null" if label.nil?
        "### #{label}\n#{text}"
      end
      .join("\n\n")
  end
end
