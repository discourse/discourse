# frozen_string_literal: true

module DesignWizard
  # Builds the light/dark palette pairs the design wizard offers for a theme.
  # Themes shipping their own palettes (e.g. Horizon) get those, paired by the
  # "<name>"/"<name> Dark" convention; other themes get a curated set of
  # built-in palettes, which only exist in memory (negative ids) until an
  # admin picks one and it is materialized as a via_wizard color scheme.
  class PalettePairs
    DARK_NAME_SUFFIX = " Dark"

    BUILT_IN_PAIRS = [
      { key: "default", light: "Light", dark: "Dark" },
      { key: "wcag", light: "WCAG", dark: "WCAG Dark" },
      { key: "solarized", light: "Solarized Light", dark: "Solarized Dark" },
      { key: "dracula", light: nil, dark: "Dracula" },
    ].freeze

    def self.for_theme(theme)
      owned = ColorScheme.includes(:color_scheme_colors).where(theme_id: theme.id).order(:id).to_a
      owned.present? ? new(theme).theme_pairs(owned) : new(theme).built_in_pairs
    end

    def initialize(theme)
      @theme = theme
    end

    def theme_pairs(schemes)
      schemes
        .group_by { |scheme| scheme.name.delete_suffix(DARK_NAME_SUFFIX) }
        .map do |base_name, members|
          light = members.find { |scheme| !scheme.name.end_with?(DARK_NAME_SUFFIX) }
          dark = members.find { |scheme| scheme.name.end_with?(DARK_NAME_SUFFIX) }

          pair(key: base_name.parameterize.underscore, name: base_name, light: light, dark: dark)
        end
    end

    def built_in_pairs
      BUILT_IN_PAIRS.map do |definition|
        pair(
          key: definition[:key],
          name: I18n.t("design_wizard.palette_pairs.#{definition[:key]}"),
          light: built_in_scheme(definition[:light]),
          dark: built_in_scheme(definition[:dark]),
        )
      end
    end

    private

    def pair(key:, name:, light:, dark:)
      {
        key: key,
        name: name,
        dark_only: light.nil?,
        light: serialize_scheme(light),
        dark: serialize_scheme(dark),
      }
    end

    def serialize_scheme(scheme)
      return if scheme.nil?

      { id: scheme.id, name: scheme.name, colors: ColorScheme.sort_colors(scheme.resolved_colors) }
    end

    def built_in_scheme(name)
      return if name.nil?

      base_scheme_id = ColorScheme::NAMES_TO_ID_MAP[name]
      ColorScheme.find_by(base_scheme_id: base_scheme_id, via_wizard: true) ||
        ColorScheme.base_color_schemes.find { |scheme| scheme.base_scheme_id == base_scheme_id }
    end
  end
end
