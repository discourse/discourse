# frozen_string_literal: true

# Design System color schemes.
#
#  1. Ensure the Light/Dark schemes exist as real, selectable records (so they
#     can be assigned to a theme).
#  2. Keep their anchors in sync with the design-system tokens. The scheme is a
#     projection of DesignSystem::Tokens, so we resync on every seed —
#     create_from_base only sets the colors once, at creation. Ramps
#     (primary-50..900, tertiary-low, …) are recomputed from the anchors.
#  3. When `enable_design_system` is on, make them the active palette by assigning
#     them to the *default* theme — whichever theme that is, not a hardcoded one —
#     so the design system declares the site's colors.
#
# Idempotent and not gated on a fresh database, so it also applies to existing
# installs. (A site_setting_changed handler that re-applies / restores on toggle
# is a follow-up; this covers fresh installs and the enabled-by-default state.)
scheme_ids =
  {
    "Design System Light" => [:light, I18n.t("color_schemes.design_system_light")],
    "Design System Dark" => [:dark, I18n.t("color_schemes.design_system_dark")],
  }.to_h do |base_name, (mode, display_name)|
    base_scheme_id = ColorScheme::NAMES_TO_ID_MAP[base_name]
    scheme =
      ColorScheme.find_by(base_scheme_id: base_scheme_id) ||
        ColorScheme.create_from_base(
          name: display_name,
          via_wizard: true,
          base_scheme_id: base_scheme_id,
        )

    # Resync only when the anchors differ, so a no-op seed doesn't bump the scheme
    # version and needlessly recompile stylesheets.
    target = DesignSystem::Tokens.color_scheme(mode)
    current = scheme.color_scheme_colors.to_h { |c| [c.name, c.hex&.downcase] }
    if target.any? { |name, hex| current[name] != hex.downcase }
      ColorSchemeRevisor.revise(scheme, colors: target.map { |name, hex| { name:, hex: } })
    end

    [base_name, scheme.id]
  end

if SiteSetting.enable_design_system
  Theme.find_default&.update!(
    color_scheme_id: scheme_ids["Design System Light"],
    dark_color_scheme_id: scheme_ids["Design System Dark"],
  )
end
