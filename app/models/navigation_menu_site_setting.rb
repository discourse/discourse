# frozen_string_literal: true

class NavigationMenuSiteSetting < EnumSiteSetting
  SIDEBAR = "sidebar"
  HEADER_DROPDOWN = "header dropdown"

  class << self
    def valid_value?(val)
      values.any? { |v| v[:value] == val }
    end

    def values
      @values ||= [
        { name: "admin.navigation_menu.sidebar", value: SIDEBAR },
        { name: "admin.navigation_menu.header_dropdown", value: HEADER_DROPDOWN },
      ]
    end

    def translate_names?
      true
    end
  end
end
