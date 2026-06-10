# frozen_string_literal: true

module DiscourseGifs
  REPO_URL = "https://github.com/discourse/discourse-gifs"
  COMPONENT_NAME = "discourse-gifs"
  REMOTE_URLS = [REPO_URL, "#{REPO_URL}.git"].freeze

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
