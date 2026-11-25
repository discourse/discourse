# frozen_string_literal: true

class Blog::BlogTheme::Policy::CustomThemesAllowed < Service::PolicyBase
  def call
    SiteSetting.blog_custom_themes_enabled || context[:theme]&.dig("preset").present?
  end

  def reason
    I18n.t("blog.themes.custom_unavailable")
  end
end
