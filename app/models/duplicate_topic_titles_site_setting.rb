# frozen_string_literal: true

class DuplicateTopicTitlesSiteSetting < EnumSiteSetting
  DISALLOWED = "disallowed"
  ALLOWED_ACROSS_CATEGORIES = "allowed_across_categories"
  ALLOWED = "allowed"

  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "admin.duplicate_topic_titles.disallowed", value: DISALLOWED },
      {
        name: "admin.duplicate_topic_titles.allowed_across_categories",
        value: ALLOWED_ACROSS_CATEGORIES,
      },
      { name: "admin.duplicate_topic_titles.allowed", value: ALLOWED },
    ]
  end

  def self.translate_names?
    true
  end

  wrap_values!
end
