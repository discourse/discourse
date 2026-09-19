# frozen_string_literal: true

# Every save re-states the whole offering, so palettes an admin made selectable
# outside the wizard are reset too.
#
# update_all skips callbacks deliberately: user_selectable does not affect
# compiled CSS, and the caller expires the one cache that matters. ColorScheme's
# default scope excludes remote copies, which is what keeps this from bypassing
# no_edits_for_remote_copies.
class DesignWizard::Action::UpdatePaletteSelectability < Service::ActionBase
  option :theme
  option :selectable

  def call
    revoke_palettes_no_longer_offered
    offered.update_all(user_selectable: selectable)
  end

  private

  def offered
    @offered ||=
      begin
        theme_palettes = ColorScheme.where(theme_id: theme.id)
        theme_palettes.none? ? ColorScheme.where(via_wizard: true) : theme_palettes
      end
  end

  def revoke_palettes_no_longer_offered
    ColorScheme
      .where(theme_id: Theme::CORE_THEMES.values)
      .or(ColorScheme.where(via_wizard: true))
      .where.not(id: offered.select(:id))
      .update_all(user_selectable: false)
  end
end
