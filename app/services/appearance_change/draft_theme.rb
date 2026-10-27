# frozen_string_literal: true

# Saves a new theme with its own light and dark palettes without making it the
# default, so it can be previewed before AppearanceChange::Activate makes it
# live. With no files of its own, the theme looks like core's default design.
class AppearanceChange::DraftTheme
  include Service::Base

  params base_class: AppearanceChange::PalettesContract

  policy :can_create_theme
  policy :local_themes_allowed
  policy :can_create_color_scheme

  transaction do
    model :light_color_scheme, :create_light_color_scheme
    model :dark_color_scheme, :create_dark_color_scheme
    model :theme, :create_theme
    model :appearance_change, :create_appearance_change
    step :log_theme_creation
  end

  step :refresh_theme_site_settings

  private

  def can_create_theme(guardian:)
    guardian.can_create_theme?
  end

  # sites that only allow themes from approved repositories can't add local ones
  def local_themes_allowed
    Theme.allowed_remote_theme_ids.nil?
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

  def create_theme(params:, guardian:, light_color_scheme:, dark_color_scheme:)
    Theme.create(
      name: params.name,
      user: guardian.user,
      color_scheme: light_color_scheme,
      dark_color_scheme:,
    )
  end

  def create_appearance_change(params:, guardian:, theme:, light_color_scheme:, dark_color_scheme:)
    AppearanceChange.create(
      kind: :theme,
      name: params.name,
      theme:,
      light_color_scheme:,
      dark_color_scheme:,
      site_settings: params.site_settings_to_apply,
      user: guardian.user,
    )
  end

  def log_theme_creation(guardian:, theme:)
    StaffActionLogger.new(guardian.user).log_theme_change(nil, theme)
  end

  def refresh_theme_site_settings
    SiteSetting.refresh!(refresh_site_settings: false, refresh_theme_site_settings: true)
  end
end
