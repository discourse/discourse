# frozen_string_literal: true

module DesignWizard
  class Themes
    # Remote themes the wizard can offer next to the core themes, each behind its
    # own hidden site setting while they're tested more broadly
    INSTALLABLE = [
      {
        id: "concord",
        setting: :concord_in_wizard,
        name: "Concord",
        remote_url: "https://github.com/discourse/discourse-concord-theme",
        default_homepage: "chat",
        description_key: "design_wizard.themes.concord.description",
        screenshot_light_url: "/images/design-wizard/concord-light.webp",
        screenshot_dark_url: "/images/design-wizard/concord-dark.webp",
      }.freeze,
      {
        id: "places",
        setting: :places_in_wizard,
        name: "Go Places",
        remote_url: "https://github.com/nolosb/discourse-places-theme",
        default_homepage: "latest",
        palettes_from: "horizon",
        description_key: "design_wizard.themes.places.description",
        screenshot_light_url: "/images/design-wizard/places-light.webp",
        screenshot_dark_url: "/images/design-wizard/places-dark.webp",
      }.freeze,
    ].freeze

    def self.selectable
      Theme.where(id: Theme::CORE_THEMES.values).or(installed)
    end

    def self.ids
      Theme::CORE_THEMES.values + installed.pluck(:id)
    end

    def self.available_to_install(themes, guardian:)
      return [] if !guardian.can_create_theme?

      enabled.filter_map do |definition|
        next if !guardian.allowed_theme_repo_import?(definition[:remote_url])
        next if themes.any? { |theme| definition_for(theme) == definition }

        definition.except(:setting, :palettes_from).merge(
          screenshot_light_url: Discourse.base_path + definition[:screenshot_light_url],
          screenshot_dark_url: Discourse.base_path + definition[:screenshot_dark_url],
          description: I18n.t(definition[:description_key]),
          palette_pairs: [],
        )
      end
    end

    def self.definition_for(theme)
      remote_url = theme.remote_theme&.remote_url&.delete_suffix(".git")
      return if remote_url.blank?

      enabled.find { |definition| definition[:remote_url] == remote_url }
    end

    # A theme without palettes of its own can offer a core theme's palettes; it
    # points at them instead of copying them
    def self.palette_owner_id(theme)
      return if theme.nil?

      Theme::CORE_THEMES.fetch(definition_for(theme)&.dig(:palettes_from), theme.id)
    end

    def self.enabled
      INSTALLABLE.select { |definition| SiteSetting.public_send(definition[:setting]) }
    end
    private_class_method :enabled

    def self.installed
      remote_urls =
        enabled.flat_map do |definition|
          [definition[:remote_url], "#{definition[:remote_url]}.git"]
        end
      return Theme.none if remote_urls.empty?

      Theme.where(
        component: false,
        remote_theme_id: RemoteTheme.where(remote_url: remote_urls).select(:id),
      )
    end
    private_class_method :installed
  end
end
