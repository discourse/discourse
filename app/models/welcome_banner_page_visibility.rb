# frozen_string_literal: true

require "enum_site_setting"

class WelcomeBannerPageVisibility < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    @values ||= [
      { name: "welcome_banner_page_visibility.top_menu_pages", value: "top_menu_pages" },
      { name: "welcome_banner_page_visibility.homepage", value: "homepage" },
      { name: "welcome_banner_page_visibility.discovery", value: "discovery" },
      { name: "welcome_banner_page_visibility.all_pages", value: "all_pages" },
    ]
  end

  def self.translate_names?
    true
  end
end
