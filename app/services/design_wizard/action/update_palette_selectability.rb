# frozen_string_literal: true

# Updating one offering preserves the availability of other palettes.
#
# Only palettes for the modes the site offers stay selectable: a member's
# personal pick outranks the theme's palettes, so a selectable dark palette on a
# light-only site would still turn the site dark for that member.
#
# update_all skips callbacks deliberately: user_selectable does not affect
# compiled CSS, and the caller expires the one cache that matters. ColorScheme's
# default scope excludes remote copies, which is what keeps this from bypassing
# no_edits_for_remote_copies.
class DesignWizard::Action::UpdatePaletteSelectability < Service::ActionBase
  option :theme
  option :selectable
  option :light, default: -> { true }
  option :dark, default: -> { true }

  def call
    dark_ids = offered.includes(:color_scheme_colors).select(&:is_dark?).map(&:id)

    offered.where(id: dark_ids).update_all(user_selectable: selectable && dark)
    offered.where.not(id: dark_ids).update_all(user_selectable: selectable && light)
  end

  private

  def offered
    @offered ||=
      begin
        theme_palettes = ColorScheme.where(theme_id: theme.id)
        theme_palettes.none? ? ColorScheme.where(via_wizard: true) : theme_palettes
      end
  end
end
