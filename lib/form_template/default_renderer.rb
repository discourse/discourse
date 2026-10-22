# frozen_string_literal: true

class FormTemplate::DefaultRenderer
  def self.render(field_values)
    field_values
      .fields
      .filter_map do |field|
        value = field_values.answers[field.fetch("id")]
        if (value.nil? && !field_values.number_formats.key?(field["id"])) || value == false ||
             value == []
          next
        end

        text =
          case value
          when true
            "on"
          when Array
            value.join("\n")
          else
            value.to_s
          end

        text = field_values.number_formats.fetch(field["id"], text)

        # Empty successful controls leave a separator in the existing browser formatter.
        next "" if text.empty?

        label = field.fetch("attributes", {}).fetch("label", "undefined")
        label = "null" if label.nil?
        "### #{label}\n#{text}"
      end
      .join("\n\n")
  end
end
