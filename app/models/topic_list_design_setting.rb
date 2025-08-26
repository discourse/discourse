# frozen_string_literal: true

require "enum_site_setting"

class TopicListDesignSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    @values ||= [
      { name: "topic_list_design.topic_table", value: "topic_table" },
      { name: "topic_list_design.topic_cards", value: "topic_cards" },
    ]
  end

  def self.translate_names?
    true
  end
end
