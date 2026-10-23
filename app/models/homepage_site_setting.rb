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
      DiscoursePluginRegistry
        .homepage_options
        .select { |option| offered?(option) }
        .map { |option| { name: option[:name], value: option[:id] } }
  end

  def self.choices
    values.filter_map { |entry| entry[:value].presence }
  end

  def self.translate_names?
    true
  end

  def self.offered?(option)
    option[:enabled].nil? || !!option[:enabled].call
  rescue StandardError => e
    # The homepage is resolved from these choices on every page load, so a
    # failing condition must not take the site down with it.
    Discourse.warn_exception(e, message: "Homepage enabled check failed for '#{option[:id]}'")
    false
  end
  private_class_method :offered?
end
