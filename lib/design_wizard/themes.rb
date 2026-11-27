# frozen_string_literal: true

module DesignWizard
  class Themes
    CONCORD = {
      default_homepage: "chat",
      description_key: "design_wizard.themes.concord.description",
      screenshot_light_url: "/images/design-wizard/concord-light.webp",
      screenshot_dark_url: "/images/design-wizard/concord-dark.webp",
    }.freeze

    CONCORD_REMOTE_URLS = %w[
      https://github.com/discourse/discourse-concord-theme
      https://github.com/discourse/discourse-concord-theme.git
      ssh://git@github.com/discourse/discourse-concord-theme
      ssh://git@github.com/discourse/discourse-concord-theme.git
    ].freeze

    def self.selectable
      themes = Theme::CORE_THEMES
      default_id = SiteSetting.default_theme_id
      if default_id.positive? && installed_concord.exists?(default_id)
        themes = themes.merge("concord" => default_id)
      end
      Theme.where(id: themes.values)
    end

    def self.ids
      Theme::CORE_THEMES.values + installed_concord.pluck(:id)
    end

    def self.definition_for(theme)
      if theme.id == Theme::CORE_THEMES.fetch("concord") ||
           CONCORD_REMOTE_URLS.include?(
             theme.remote_theme&.remote_url.to_s.downcase.delete_suffix("/"),
           )
        CONCORD
      end
    end

    def self.installed_concord
      remote_ids =
        RemoteTheme.where("lower(rtrim(remote_url, '/')) IN (?)", CONCORD_REMOTE_URLS).select(:id)
      Theme.where(component: false, remote_theme_id: remote_ids)
    end
    private_class_method :installed_concord
  end
end
