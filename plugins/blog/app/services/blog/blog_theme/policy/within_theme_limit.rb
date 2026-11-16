# frozen_string_literal: true

class Blog::BlogTheme::Policy::WithinThemeLimit < Service::PolicyBase
  def call
    Blog::BlogTheme.count < Blog::BlogTheme::MAX_THEMES
  end

  def reason
    I18n.t("blog.themes.limit")
  end
end
