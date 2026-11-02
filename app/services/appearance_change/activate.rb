# frozen_string_literal: true

# Makes a saved appearance change live and records what it replaces so
# AppearanceChange::Revert can switch back.
#
# Apply site settings before assigning palettes and recording activation,
# so a failed font update leaves the original state intact for a retry.
class AppearanceChange::Activate
  include Service::Base

  params do
    attribute :appearance_change_id, :integer

    validates :appearance_change_id, presence: true
  end

  model :appearance_change
  policy :can_edit_theme
  policy :not_applied
  policy :palettes_exist
  model :replaced_state
  only_if(:changes_site_settings) { step :apply_site_settings }

  transaction do
    only_if(:changes_palettes) { step :assign_palettes }
    step :record_activation
  end

  private

  def fetch_appearance_change(params:)
    AppearanceChange.includes(:theme).find_by(id: params.appearance_change_id)
  end

  def can_edit_theme(guardian:, appearance_change:)
    guardian.can_edit_theme?(appearance_change.theme)
  end

  def not_applied(appearance_change:)
    !appearance_change.applied?
  end

  def palettes_exist(appearance_change:)
    appearance_change.palettes_exist?
  end

  def fetch_replaced_state(appearance_change:)
    appearance_change.replaced_state
  end

  def changes_palettes(appearance_change:)
    !appearance_change.kind_theme?
  end

  def assign_palettes(appearance_change:)
    appearance_change.theme.update!(
      color_scheme: appearance_change.light_color_scheme,
      dark_color_scheme: appearance_change.dark_color_scheme,
    )
  end

  def record_activation(appearance_change:, replaced_state:)
    appearance_change.update!(previous_state: replaced_state, activated_at: Time.zone.now)
  end

  def changes_site_settings(appearance_change:)
    appearance_change.activation_site_settings.present?
  end

  # default_theme_id is hidden, so it has to be explicitly allowed.
  def apply_site_settings(appearance_change:, guardian:)
    SiteSetting::Update.call(
      params: {
        settings:
          appearance_change.activation_site_settings.map do |setting_name, value|
            { setting_name:, value: }
          end,
      },
      options: {
        allow_changing_hidden: %i[default_theme_id],
      },
      guardian:,
    ) { on_failure { fail!("failed to update site settings") } }
  end
end
