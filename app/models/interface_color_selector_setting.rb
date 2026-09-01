# frozen_string_literal: true

require "enum_site_setting"

class InterfaceColorSelectorSetting < EnumSiteSetting
  class << self
    def valid_value?(val)
      values.any? { |v| v[:value].to_s == val.to_s }
    end

    def values
      @values ||= [
        { name: "interface_color_selector.disabled", value: "disabled" },
        { name: "interface_color_selector.sidebar_footer", value: "sidebar_footer" },
        { name: "interface_color_selector.header", value: "header" },
      ]
    end

    def translate_names?
      true
    end

    def enabled?
      SiteSetting.interface_color_selector != "disabled"
    end
  end
end
