# frozen_string_literal: true

module DesignWizard
  class Themes
    CONCORD = {
      name: "Concord",
      remote_url: "https://github.com/discourse/discourse-concord-theme",
      supports_welcome_banner: false,
      supports_search: false,
      screenshot_light_url: "/images/design-wizard/concord-light.webp",
      screenshot_dark_url: "/images/design-wizard/concord-dark.webp",
    }.freeze

    def self.selectable
      Theme.where(id: Theme::CORE_THEMES.values).or(installed_concord)
    end

    def self.ids
      Theme::CORE_THEMES.values + installed_concord.pluck(:id)
    end

    def self.available_to_install(themes, guardian:)
      return [] if !SiteSetting.concord_in_wizard || !guardian.can_create_theme?
      return [] if !guardian.allowed_theme_repo_import?(CONCORD[:remote_url])
      return [] if themes.any? { |theme| definition_for(theme) }

      [
        CONCORD.merge(
          screenshot_light_url: Discourse.base_path + CONCORD[:screenshot_light_url],
          screenshot_dark_url: Discourse.base_path + CONCORD[:screenshot_dark_url],
          id: "concord",
          description: I18n.t("design_wizard.themes.concord.description"),
          palette_pairs: [],
        ),
      ]
    end

    def self.definition_for(theme)
      return if !SiteSetting.concord_in_wizard

      CONCORD if theme.remote_theme&.remote_url&.delete_suffix(".git") == CONCORD[:remote_url]
    end

    def self.installed_concord
      return Theme.none if !SiteSetting.concord_in_wizard

      Theme.where(
        component: false,
        remote_theme_id:
          RemoteTheme.where(
            remote_url: [CONCORD[:remote_url], "#{CONCORD[:remote_url]}.git"],
          ).select(:id),
      )
    end
    private_class_method :installed_concord
  end
end
