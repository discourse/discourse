# frozen_string_literal: true

# Saves styles for a theme the site keeps, such as Horizon, as a disabled
# component attached to it, so they can be previewed with
# `?preview_component_ids=` before AppearanceChange::Activate enables the
# component. It can also bring new palettes for the theme, which are given
# to it when the change goes live.
#
# Styles are typed (see AppearanceStyles::Policy), never CSS, and are checked
# for the theme before anything is saved. With replaces_theme_id, the
# component is a new version of one an earlier change created, saved as
# "Name (draft)" until it is made live.
class AppearanceChange::DraftComponent
  include Service::Base

  # Themes styles can be added to as a component. Others get a new theme
  # with AppearanceChange::DraftTheme.
  SUPPORTED_PARENT_THEME_IDS = [Theme::CORE_THEMES["horizon"]].freeze

  params base_class: AppearanceChange::Contract do
    attribute :parent_theme_id, :integer
    attribute :styles
    attribute :replaces_theme_id, :integer
    attribute :light_colors, :hash, &AppearanceChange::PalettesContract::PALETTE
    attribute :dark_colors, :hash, &AppearanceChange::PalettesContract::PALETTE

    validates :parent_theme_id, presence: true
    validate :both_palettes_or_neither

    def palettes?
      light_colors.present?
    end

    def light_palette_colors
      palette_colors(light_colors)
    end

    def dark_palette_colors
      palette_colors(dark_colors)
    end

    private

    def both_palettes_or_neither
      return if light_colors.present? == dark_colors.present?
      errors.add(:dark_colors, :blank)
    end

    def palette_colors(palette)
      palette.to_hash.map { |color_name, hex| { name: color_name.to_s, hex: hex.downcase } }
    end
  end

  model :parent_theme
  policy :supported_parent_theme
  policy :can_create_theme
  policy :local_themes_allowed
  only_if(:new_palettes) { policy :can_create_color_scheme }
  only_if(:new_version) { policy :replaceable_component }
  step :check_styles

  transaction do
    only_if(:new_palettes) do
      model :light_color_scheme, :create_light_color_scheme
      model :dark_color_scheme, :create_dark_color_scheme
    end
    model :component, :create_component
    step :attach_component
    model :appearance_change, :create_appearance_change
    step :log_theme_creation
  end

  private

  def fetch_parent_theme(params:)
    Theme.find_by(id: params.parent_theme_id, component: false)
  end

  def supported_parent_theme(guardian:, parent_theme:)
    SUPPORTED_PARENT_THEME_IDS.include?(parent_theme.id) && guardian.can_edit_theme?(parent_theme)
  end

  def can_create_theme(guardian:)
    guardian.can_create_theme?
  end

  def local_themes_allowed
    Theme.allowed_remote_theme_ids.nil?
  end

  def new_palettes(params:)
    params.palettes?
  end

  def can_create_color_scheme(guardian:)
    guardian.can_create_color_scheme?
  end

  def new_version(params:)
    params.replaces_theme_id.present?
  end

  def replaceable_component(params:, guardian:, parent_theme:)
    replaced =
      AppearanceChange.kind_component.find_by(
        theme_id: params.replaces_theme_id,
        parent_theme_id: parent_theme.id,
      )
    replaced.present? && replaced.theme_unchanged? && !replaced.theme.user_selectable? &&
      guardian.can_edit_theme?(replaced.theme)
  end

  # Checked against the palettes the theme will show: the new ones, or its
  # current ones.
  def check_styles(params:, parent_theme:)
    return context[:css] = "" if params.styles.blank?

    palettes =
      if params.palettes?
        { light: params.light_colors.to_hash, dark: params.dark_colors.to_hash }
      else
        {
          light: parent_theme.color_scheme&.resolved_colors,
          dark: parent_theme.dark_color_scheme&.resolved_colors,
        }.compact
      end
    result =
      AppearanceStyles::Policy.call(
        params.styles,
        palettes: palettes.presence,
        base_theme_id: parent_theme.id,
      )
    fail!(result.errors.join("\n")) if !result.valid?
    context[:css] = result.css
  end

  def create_light_color_scheme(params:)
    ColorScheme.create(name: params.name, colors: params.light_palette_colors)
  end

  def create_dark_color_scheme(params:)
    ColorScheme.create(
      name: AppearanceChange.dark_palette_name(params.name),
      colors: params.dark_palette_colors,
    )
  end

  # The compile is the last check: a component that saves with an SCSS error
  # would show without its styles.
  def create_component(params:, guardian:, css:)
    name =
      params.replaces_theme_id ? AppearanceChange.version_name(params.name, :draft) : params.name
    component = Theme.create(name:, user: guardian.user, component: true, enabled: false)
    return component if css.blank? || !component.persisted?

    component.set_field(target: :common, name: :scss, value: css)
    component.save!
    error = component.theme_fields.find_by(target_id: Theme.targets[:common], name: "scss")&.error
    fail!(error) if error.present?
    component
  end

  def attach_component(parent_theme:, component:)
    parent_theme.add_relative_theme!(:child, component)
  end

  def create_appearance_change(params:, guardian:, parent_theme:, component:, css:)
    AppearanceChange.create(
      kind: :component,
      name: params.name,
      theme: component,
      parent_theme:,
      light_color_scheme: context[:light_color_scheme],
      dark_color_scheme: context[:dark_color_scheme],
      site_settings: params.site_settings_to_apply,
      styles: css.present? ? params.styles.deep_stringify_keys : {},
      css:,
      replaces_theme_id: params.replaces_theme_id,
      user: guardian.user,
    )
  end

  def log_theme_creation(guardian:, component:)
    StaffActionLogger.new(guardian.user).log_theme_change(nil, component)
  end
end
