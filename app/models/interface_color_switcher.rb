# frozen_string_literal: true

require "enum_site_setting"

class InterfaceColorSwitcher < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    @values ||= [
      { name: "interface_color_switcher.off", value: "off" },
      { name: "interface_color_switcher.sidebar_footer", value: "sidebar_footer" },
      { name: "interface_color_switcher.header", value: "header" },
    ]
  end

  def self.translate_names?
    true
  end

  def self.enabled?
    SiteSetting.interface_color_switcher != "off"
  end
end
