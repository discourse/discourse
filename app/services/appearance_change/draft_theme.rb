# frozen_string_literal: true

# Saves a new theme with its own light and dark palettes without making it the
# default, so it can be previewed before AppearanceChange::Activate makes it
# live. Without styles, the theme looks like core's default design.
#
# Styles are typed (see AppearanceStyles::Policy), never CSS, and are checked
# against the new palettes before anything is saved.
#
# With replaces_theme_id, the theme is a new version of one an earlier change
# created, saved as "Name (draft)" until it is made live.
class AppearanceChange::DraftTheme
  include Service::Base

  params base_class: AppearanceChange::PalettesContract do
    attribute :styles
    attribute :base_theme_id, :integer
    attribute :replaces_theme_id, :integer
  end

  policy :can_create_theme
  policy :local_themes_allowed
  policy :can_create_color_scheme
  step :resolve_base_theme
  policy :supported_base_theme
  only_if(:new_version) { policy :replaceable_theme }
  step :check_styles

  transaction do
    model :light_color_scheme, :create_light_color_scheme
    model :dark_color_scheme, :create_dark_color_scheme
    model :theme, :create_theme
    step :add_styles
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

  def resolve_base_theme(params:)
    source = Theme.find_by(id: params.replaces_theme_id) || Theme.find_default
    context[:base_theme_id] = params.base_theme_id
    if params.base_theme_id.nil? && params.replaces_theme_id.present? &&
         AppearanceStyles::SyncedTheme.horizon?(source)
      context[:base_theme_id] = Theme::CORE_THEMES["horizon"]
    end
    context[:source_theme] = source
  end

  def supported_base_theme(base_theme_id:, guardian:, source_theme:)
    base_theme_id.nil? ||
      (
        base_theme_id == Theme::CORE_THEMES["horizon"] &&
          guardian.can_edit_theme?(Theme.horizon_theme) && source_theme &&
          AppearanceStyles::SyncedTheme.horizon?(source_theme) &&
          guardian.can_edit_theme?(source_theme) &&
          source_theme.child_themes.all? { |component| guardian.can_edit_theme?(component) } &&
          guardian.can_edit_theme_relations?(
            source_theme,
            child_theme_ids: source_theme.child_theme_ids,
          )
      )
  end

  def new_version(params:)
    params.replaces_theme_id.present?
  end

  def replaceable_theme(params:, guardian:)
    theme = Theme.find_by(id: params.replaces_theme_id, component: false)
    AppearanceChange.replaceable?(theme) && guardian.can_edit_theme?(theme)
  end

  def check_styles(params:, base_theme_id:)
    return context[:css] = "" if params.styles.blank?

    result =
      AppearanceStyles::Policy.call(
        params.styles,
        base_theme_id:,
        palettes: {
          light: params.light_colors.to_hash,
          dark: params.dark_colors.to_hash,
        },
      )
    fail!(result.errors.join("\n")) if !result.valid?
    context[:css] = result.css
  end

  def create_light_color_scheme(params:)
    ColorScheme.create(name: params.name, colors: params.light_palette_colors)
  end

  def create_dark_color_scheme(params:)
    ColorScheme.create(name: params.dark_palette_name, colors: params.dark_palette_colors)
  end

  def create_theme(params:, guardian:, light_color_scheme:, dark_color_scheme:)
    Theme.create(
      name:
        params.replaces_theme_id ? AppearanceChange.version_name(params.name, :draft) : params.name,
      user: guardian.user,
      color_scheme: light_color_scheme,
      dark_color_scheme:,
    )
  end

  # The compile is the last check: a theme that saves with an SCSS error
  # would show without its styles.
  def add_styles(theme:, css:, params:, source_theme:, base_theme_id:)
    if base_theme_id
      AppearanceStyles::SyncedTheme.create!(
        theme:,
        source: source_theme,
        # stored the same way as on the change, so the two match
        styles: css.present? ? params.styles || {} : {},
        css:,
      )
    else
      return if css.blank?

      theme.set_field(target: :common, name: :scss, value: css)
      theme.save!
    end

    error = theme.theme_fields.find_by(target_id: Theme.targets[:common], name: "scss")&.error
    fail!(error) if error.present?
  end

  def create_appearance_change(
    params:,
    guardian:,
    theme:,
    light_color_scheme:,
    dark_color_scheme:,
    css:,
    base_theme_id:
  )
    AppearanceChange.create(
      kind: :theme,
      name: params.name,
      theme:,
      light_color_scheme:,
      dark_color_scheme:,
      site_settings: params.site_settings_to_apply,
      styles: css.present? ? params.styles.deep_stringify_keys : {},
      css:,
      replaces_theme_id: params.replaces_theme_id,
      base_theme_id:,
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
