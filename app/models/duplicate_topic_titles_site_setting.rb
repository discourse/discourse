# frozen_string_literal: true

class DuplicateTopicTitlesSiteSetting < EnumSiteSetting
  DISALLOWED = "disallowed"
  ALLOWED_ACROSS_CATEGORIES = "allowed_across_categories"
  ALLOWED = "allowed"

  class << self
    def valid_value?(val)
      values.any? { |v| v[:value] == val }
    end

    def values
      @values ||= [
        { name: "admin.duplicate_topic_titles.disallowed", value: DISALLOWED },
        {
          name: "admin.duplicate_topic_titles.allowed_across_categories",
          value: ALLOWED_ACROSS_CATEGORIES,
        },
        { name: "admin.duplicate_topic_titles.allowed", value: ALLOWED },
      ]
    end

    def translate_names?
      true
    end
  end

  wrap_values!
end
