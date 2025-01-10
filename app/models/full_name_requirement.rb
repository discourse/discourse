# frozen_string_literal: true

require "enum_site_setting"

class FullNameRequirement < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "full_name_requirement.required_at_signup", value: "required_at_signup" },
      { name: "full_name_requirement.optional_at_signup", value: "optional_at_signup" },
      { name: "full_name_requirement.hidden_at_signup", value: "hidden_at_signup" },
    ]
  end

  def self.translate_names?
    true
  end
end
