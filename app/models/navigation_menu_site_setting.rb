# frozen_string_literal: true

class NavigationMenuSiteSetting < EnumSiteSetting
  SIDEBAR = "sidebar"
  HEADER_DROPDOWN = "header dropdown"
  LEGACY = "legacy"

  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "admin.navigation_menu.sidebar", value: SIDEBAR },
      { name: "admin.navigation_menu.header_dropdown", value: HEADER_DROPDOWN },
      { name: "admin.navigation_menu.legacy", value: LEGACY },
    ]
  end

  def self.translate_names?
    true
  end
end
