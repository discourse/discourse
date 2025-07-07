# frozen_string_literal: true

require "enum_site_setting"

class InterfaceWelcomeBannerLocation < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    @values ||= [
      {
        name: "interface_welcome_banner_location.above_topic_content",
        value: "above_topic_content",
      },
      { name: "interface_welcome_banner_location.below_site_header", value: "below_site_header" },
    ]
  end

  def self.translate_names?
    true
  end
end
