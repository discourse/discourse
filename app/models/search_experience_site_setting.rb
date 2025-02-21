# frozen_string_literal: true

class SearchExperienceSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "search.experience.search_field", value: "search_field" },
      { name: "search.experience.search_icon", value: "search_icon" },
    ]
  end

  def self.translate_names?
    true
  end
end
