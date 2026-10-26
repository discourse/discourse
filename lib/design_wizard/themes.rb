# frozen_string_literal: true

module DesignWizard
  class Themes
    REMOTE_THEMES = {
      "concord" => {
        name: "Concord",
        remote_url: "https://github.com/discourse/discourse-concord-theme",
      },
    }.freeze

    def self.installed
      Theme.where(id: Theme::CORE_THEMES.values).or(remote)
    end

    def self.ids
      Theme::CORE_THEMES.values + remote.pluck(:id)
    end

    def self.available_to_install(themes, guardian:)
      return [] if !guardian.can_create_theme?

      installed_urls =
        themes.filter_map { |theme| theme.remote_theme&.remote_url&.delete_suffix(".git") }

      REMOTE_THEMES.filter_map do |key, definition|
        next if installed_urls.include?(definition[:remote_url])
        next if !guardian.allowed_theme_repo_import?(definition[:remote_url])

        definition.merge(
          id: key,
          description: I18n.t("design_wizard.themes.#{key}.description"),
          palette_pairs: [],
        )
      end
    end

    def self.remote
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
