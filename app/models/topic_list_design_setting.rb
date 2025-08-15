# frozen_string_literal: true

require "enum_site_setting"

class TopicListDesignSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "topic_list_design.topic_table", value: 0 },
      { name: "topic_list_design.topic_cards", value: 1 },
    ]
  end

  def self.translate_names?
    true
  end
end
