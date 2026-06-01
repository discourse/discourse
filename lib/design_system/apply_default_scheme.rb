# frozen_string_literal: true

# Applies (or restores) the Design System ColorScheme on the *default* theme to
# match `enable_design_system`. The fixture covers fresh installs / boot; this is
# what makes a runtime toggle take effect both ways.
#
# Enabling remembers the theme's prior scheme so disabling restores it, instead of
# leaving the DS palette stuck on. Idempotent: re-running with the flag unchanged
# is a no-op.
module DesignSystem
  class ApplyDefaultScheme
    STORE = "design_system"
    PREV_LIGHT = "previous_color_scheme_id"
    PREV_DARK = "previous_dark_color_scheme_id"

    def self.call(enabled = SiteSetting.enable_design_system)
      theme = Theme.find_default
      light = scheme_id("Design System Light")
      dark = scheme_id("Design System Dark")
      return if theme.nil? || light.nil?

      ds_schemes = [light, dark].compact

      if enabled
        return if theme.color_scheme_id == light && theme.dark_color_scheme_id == dark

        # Remember the non-DS scheme so disabling can restore it.
        if ds_schemes.exclude?(theme.color_scheme_id)
          PluginStore.set(STORE, PREV_LIGHT, theme.color_scheme_id)
          PluginStore.set(STORE, PREV_DARK, theme.dark_color_scheme_id)
        end
        theme.update!(color_scheme_id: light, dark_color_scheme_id: dark)
      elsif ds_schemes.include?(theme.color_scheme_id)
        # Only restore if we're the ones who assigned the DS scheme.
        theme.update!(
          color_scheme_id: PluginStore.get(STORE, PREV_LIGHT),
          dark_color_scheme_id: PluginStore.get(STORE, PREV_DARK),
        )
        PluginStore.remove(STORE, PREV_LIGHT)
        PluginStore.remove(STORE, PREV_DARK)
      end
    end

    def self.scheme_id(base_name)
      ColorScheme.find_by(base_scheme_id: ColorScheme::NAMES_TO_ID_MAP[base_name])&.id
    end
    private_class_method :scheme_id
  end
end
