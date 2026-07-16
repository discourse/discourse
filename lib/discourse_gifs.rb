# frozen_string_literal: true

module DiscourseGifs
  COMPONENT_NAME = "discourse-gifs"

  REPO_URLS = %w[
    https://github.com/discourse/discourse-gifs
    https://github.com/xfalcox/discourse-gifs
  ].freeze

  REMOTE_URLS = REPO_URLS.flat_map { |url| [url, "#{url}.git"] }.freeze

  def self.component_installed?
    component_scope.exists?
  end

  def self.component_scope
    Theme
      .joins(:remote_theme)
      .where(component: true)
      .where(remote_themes: { remote_url: REMOTE_URLS })
  end
end
