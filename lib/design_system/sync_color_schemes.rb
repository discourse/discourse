# frozen_string_literal: true

# Keeps the built-in "Design System Light/Dark" colour schemes — the ones applied
# to the active (default) theme — equal to the design-system tokens merged with
# that theme's design-system.json overrides.
#
# This makes the scheme record the single source for every consumer: the compiled
# `color_definitions` stylesheet AND Ruby readers that run before stylesheets (the
# boot splash, `<meta name="theme-color">`, email styles) which look colours up via
# ColorScheme#resolved_colors / ColorScheme.hex_for_name. No-op until the schemes
# are seeded.
module DesignSystem
  class SyncColorSchemes
    def self.call
      overrides = Theme.find_by(id: SiteSetting.default_theme_id)&.design_system_overrides || {}
      sync("Design System Light", :light, overrides)
      sync("Design System Dark", :dark, overrides)
      ColorScheme.hex_cache.clear
    end

    def self.sync(base_name, mode, overrides)
      scheme = ColorScheme.find_by(base_scheme_id: ColorScheme::NAMES_TO_ID_MAP[base_name])
      return if scheme.nil?

      anchors = Tokens.color_scheme(mode, overrides)
      current = scheme.colors_by_name
      return if anchors.all? { |name, hex| current[name]&.hex == hex }

      ColorSchemeRevisor.revise(scheme, colors: anchors.map { |name, hex| { name:, hex: } })
    end
    private_class_method :sync
  end
end
