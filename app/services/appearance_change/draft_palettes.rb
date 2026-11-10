# frozen_string_literal: true

# Saves a light and a dark palette for a theme without giving them to it yet,
# so they can be previewed before AppearanceChange::Activate makes them live.
class AppearanceChange::DraftPalettes
  include Service::Base

  params base_class: AppearanceChange::PalettesContract do
    attribute :theme_id, :integer

    validates :theme_id, presence: true
  end

  model :theme
  policy :can_edit_theme
  policy :can_create_color_scheme

  transaction do
    model :light_color_scheme, :create_light_color_scheme
    model :dark_color_scheme, :create_dark_color_scheme
    model :appearance_change, :create_appearance_change
  end

  private

  def fetch_theme(params:)
    Theme.find_by(id: params.theme_id, component: false)
  end

  def can_edit_theme(guardian:, theme:)
    guardian.can_edit_theme?(theme)
  end

  def can_create_color_scheme(guardian:)
    guardian.can_create_color_scheme?
  end

  def create_light_color_scheme(params:)
    ColorScheme.create(name: params.name, colors: params.light_palette_colors)
  end

  def create_dark_color_scheme(params:)
    ColorScheme.create(name: params.dark_palette_name, colors: params.dark_palette_colors)
  end

  def create_appearance_change(params:, guardian:, theme:, light_color_scheme:, dark_color_scheme:)
    AppearanceChange.create(
      kind: :palettes,
      name: params.name,
      theme:,
      light_color_scheme:,
      dark_color_scheme:,
      site_settings: params.site_settings_to_apply,
      user: guardian.user,
    )
  end
end
