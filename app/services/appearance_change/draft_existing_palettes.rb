# frozen_string_literal: true

# Saves a choice of a light and a dark palette the site already has for a
# theme, without giving them to it yet, so they can be previewed before
# AppearanceChange::Activate makes them live.
#
# The palettes are the ones the design wizard lets a theme use: the theme's
# own, site-wide ones, and core's built-in ones, which only exist in memory
# until they're chosen for the first time.
class AppearanceChange::DraftExistingPalettes
  include Service::Base

  params base_class: AppearanceChange::Contract do
    attribute :theme_id, :integer
    attribute :light_palette_id, :integer
    attribute :dark_palette_id, :integer

    validates :theme_id, :light_palette_id, :dark_palette_id, presence: true
  end

  model :theme
  policy :can_edit_theme
  policy :palettes_available_to_theme

  transaction do
    model :light_color_scheme, :resolve_light_color_scheme
    model :dark_color_scheme, :resolve_dark_color_scheme
    model :appearance_change, :create_appearance_change
  end

  private

  def fetch_theme(params:)
    Theme.find_by(id: params.theme_id, component: false)
  end

  def can_edit_theme(guardian:, theme:)
    guardian.can_edit_theme?(theme)
  end

  # Built-in palettes have negative ids until they're saved.
  def palettes_available_to_theme(params:, theme:)
    [params.light_palette_id, params.dark_palette_id].all? do |palette_id|
      if palette_id.negative?
        ColorScheme::NAMES_TO_ID_MAP.value?(palette_id)
      else
        ColorScheme.where(id: palette_id, theme_id: [nil, theme.id]).exists?
      end
    end
  end

  def resolve_light_color_scheme(params:)
    DesignWizard::Action::ResolvePalette.call(palette_id: params.light_palette_id)
  end

  def resolve_dark_color_scheme(params:)
    DesignWizard::Action::ResolvePalette.call(palette_id: params.dark_palette_id)
  end

  def create_appearance_change(params:, guardian:, theme:, light_color_scheme:, dark_color_scheme:)
    AppearanceChange.create(
      kind: :existing_palettes,
      name: params.name,
      theme:,
      light_color_scheme:,
      dark_color_scheme:,
      site_settings: params.site_settings_to_apply,
      user: guardian.user,
    )
  end
end
