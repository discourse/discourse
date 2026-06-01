# frozen_string_literal: true

# Design System color schemes.
#
#  1. Ensure the Light/Dark schemes exist as real, selectable records (so they
#     can be assigned to a theme).
#  2. Assign / restore them on the *default* theme to match `enable_design_system`
#     (DesignSystem::ApplyDefaultScheme) — whichever theme is default, not a
#     hardcoded one. A `site_setting_changed` handler calls the same service so a
#     runtime toggle takes effect (and restores the prior scheme when turned off).
#  3. Sync their anchors to the design-system tokens merged with the default
#     theme's design-system.json overrides (DesignSystem::SyncColorSchemes), so the
#     schemes are the single source for the stylesheet AND Ruby readers (splash,
#     theme-color, emails). Ramps (primary-50..900, tertiary-low, …) are recomputed
#     from the anchors.
#
# Idempotent and not gated on a fresh database, so it also applies to existing
# installs.
{
  "Design System Light" => I18n.t("color_schemes.design_system_light"),
  "Design System Dark" => I18n.t("color_schemes.design_system_dark"),
}.each do |base_name, display_name|
  base_scheme_id = ColorScheme::NAMES_TO_ID_MAP[base_name]
  next if ColorScheme.exists?(base_scheme_id: base_scheme_id)

  ColorScheme.create_from_base(name: display_name, via_wizard: true, base_scheme_id: base_scheme_id)
end

DesignSystem::ApplyDefaultScheme.call
DesignSystem::SyncColorSchemes.call
