# frozen_string_literal: true

require "enum_site_setting"

class HomepageSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    val == "" || values.any? { |v| v[:value] == val }
  end

  def self.values
    # A blank value means the homepage is derived from the first top_menu item.
    [{ name: "admin.homepage.top_menu_default", value: "" }] +
      TopMenu.homepage_choices.map { |f| { name: "filters.#{f}.title", value: f } } +
      DiscoursePluginRegistry.homepage_options.map do |option|
        { name: option[:name], value: option[:id] }
      end
  end

  def self.choices
    values.filter_map { |entry| entry[:value].presence }
  end

  def self.translate_names?
    true
  end
end
