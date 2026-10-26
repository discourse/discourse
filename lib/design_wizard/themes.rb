# frozen_string_literal: true

module DesignWizard
  class Themes
    REMOTE_THEMES = {
      "concord" => {
        name: "Concord",
        remote_url: "https://github.com/discourse/discourse-concord-theme",
        supports_welcome_banner: false,
        supports_search: false,
        screenshot_light_url: "/images/design-wizard/concord-light.jpg",
        screenshot_dark_url: "/images/design-wizard/concord-dark.jpg",
      },
    }.freeze

    def self.installed
      Theme.where(id: Theme::CORE_THEMES.values).or(remote)
    end

    def self.ids
      Theme::CORE_THEMES.values + remote.pluck(:id)
    end

    def self.available_to_install(themes, guardian:)
      return [] if !SiteSetting.concord_in_wizard || !guardian.can_create_theme?

      installed_urls =
        themes.filter_map { |theme| theme.remote_theme&.remote_url&.delete_suffix(".git") }

      REMOTE_THEMES.filter_map do |key, definition|
        next if installed_urls.include?(definition[:remote_url])
        next if !guardian.allowed_theme_repo_import?(definition[:remote_url])

        definition.merge(
          screenshot_light_url: Discourse.base_path + definition[:screenshot_light_url],
          screenshot_dark_url: Discourse.base_path + definition[:screenshot_dark_url],
          id: key,
          description: I18n.t("design_wizard.themes.#{key}.description"),
          palette_pairs: [],
        )
      end
    end

    def self.definition_for(theme)
      return if !SiteSetting.concord_in_wizard

      url = theme.remote_theme&.remote_url&.delete_suffix(".git")
      REMOTE_THEMES.values.find { |definition| definition[:remote_url] == url }
    end

    def self.remote
      return Theme.none if !SiteSetting.concord_in_wizard

      urls =
        REMOTE_THEMES.values.flat_map do |definition|
          [definition[:remote_url], "#{definition[:remote_url]}.git"]
        end
      Theme.where(
        component: false,
        remote_theme_id: RemoteTheme.where(remote_url: urls).select(:id),
      )
    end
    private_class_method :remote
  end
end
