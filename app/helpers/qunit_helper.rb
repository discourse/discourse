# frozen_string_literal: true

module QunitHelper
  def theme_tests
    theme_ids = request.env[:resolved_theme_ids]
    return "" if theme_ids.blank?

    skip_transformation = request.env[:skip_theme_ids_transformation]
    query = ThemeField
      .joins(:theme)
      .where(
        target_id: Theme.targets[:tests_js],
        theme_id: skip_transformation ? theme_ids : Theme.transform_ids(theme_ids)
      )
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
