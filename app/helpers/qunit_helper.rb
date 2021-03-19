# frozen_string_literal: true

module QunitHelper
  def theme_tests
    ThemeField
      .joins(:theme)
      .where(target_id: Theme.targets[:tests_js])
      .pluck(:theme_id)
      .uniq
      .map do |theme_id|
        src = "#{GlobalSetting.cdn_url}#{Discourse.base_path}/theme-javascripts/tests/#{theme_id}.js"
        "<script src='#{src}'></script>"
      end
      .join("\n")
      .html_safe
  end
end
