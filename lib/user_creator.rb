# frozen_string_literal: true

class UserCreator
  def self.clean_custom_field_values(field, field_values)
    return field_values if field_values.nil? || field_values.empty?

    if field.field_type == "dropdown"
      field.user_field_options.find_by_value(field_values)&.value
    elsif field.field_type == "multiselect"
      field_values = Array.wrap(field_values)
      bad_values = field_values - field.user_field_options.map(&:value)
      field_values - bad_values
    else
      field_values
    end
  end
end
