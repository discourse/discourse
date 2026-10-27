# frozen_string_literal: true

# Switches back from a live appearance change to what it replaced: the theme's
# previous palettes, or the previous default theme, along with the previous
# fonts. The change itself is kept, so it can be made live again.
#
# Site settings are restored after the transaction, the same way the admin
# config writes them.
class AppearanceChange::Revert
  include Service::Base

  params do
    attribute :appearance_change_id, :integer

    validates :appearance_change_id, presence: true
  end

  model :appearance_change
  policy :can_edit_theme
  policy :applied
  model :previous_state
  policy :restorable

  transaction do
    only_if(:changes_palettes) { step :restore_palettes }
    step :record_revert
  end

  only_if(:changes_site_settings) { step :restore_site_settings }

  private

  def fetch_appearance_change(params:)
    AppearanceChange.includes(:theme).find_by(id: params.appearance_change_id)
  end

  def can_edit_theme(guardian:, appearance_change:)
    guardian.can_edit_theme?(appearance_change.theme)
  end

  def applied(appearance_change:)
    appearance_change.applied?
  end

  def fetch_previous_state(appearance_change:)
    appearance_change.previous_state.presence
  end

  def restorable(appearance_change:)
    appearance_change.restorable?
  end

  def changes_palettes(appearance_change:)
    !appearance_change.kind_theme?
  end

  def restore_palettes(appearance_change:, previous_state:)
    appearance_change.theme.update!(
      color_scheme_id: previous_state["color_scheme_id"],
      dark_color_scheme_id: previous_state["dark_color_scheme_id"],
    )
  end

  def record_revert(appearance_change:)
    appearance_change.update!(previous_state: {})
  end

  def changes_site_settings(previous_state:)
    previous_state["site_settings"].present?
  end

  # default_theme_id is hidden, so it has to be explicitly allowed.
  def restore_site_settings(previous_state:, guardian:)
    SiteSetting::Update.call(
      params: {
        settings:
          previous_state["site_settings"].map { |setting_name, value| { setting_name:, value: } },
      },
      options: {
        allow_changing_hidden: %i[default_theme_id],
      },
      guardian:,
    ) { on_failure { fail!("failed to update site settings") } }
  end
end
