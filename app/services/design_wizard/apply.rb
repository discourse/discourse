# frozen_string_literal: true

# Applies the design choices made in the admin design wizard in one atomic
# operation: default theme, the theme's light/dark palettes, fonts, homepage
# and whether members can switch between the offered palettes.
class DesignWizard::Apply
  include Service::Base

  BASE_LIGHT_PALETTE_ID = ColorScheme::NAMES_TO_ID_MAP[ColorScheme::LIGHT_PALETTE_NAME]

  params do
    attribute :theme_id, :integer
    attribute :light_palette_id, :integer
    attribute :dark_palette_id, :integer
    attribute :palettes_user_selectable, :boolean, default: false
    attribute :base_font, :string
    attribute :heading_font, :string
    attribute :homepage, :string
    attribute :category_page_style, :string

    before_validation do
      # the built-in light palette is represented by a theme without an
      # assigned light palette
      self.light_palette_id = nil if light_palette_id == BASE_LIGHT_PALETTE_ID
    end

    validates :theme_id, presence: true, inclusion: { in: Theme::CORE_THEMES.values }
    validates :base_font,
              :heading_font,
              inclusion: {
                in: BaseFontSetting.values.map { |font| font[:value] },
              },
              allow_blank: true
    validates :homepage, inclusion: { in: %w[latest new hot categories] }, allow_blank: true
    validates :category_page_style,
              inclusion: {
                in: CategoryPageStyle.values.map { |style| style[:value] },
              },
              allow_blank: true
    validate :built_in_palettes_exist

    def site_settings(theme_id:)
      {
        default_theme_id: theme_id,
        base_font: base_font.presence,
        heading_font: heading_font.presence,
        default_homepage: homepage.presence,
        desktop_category_page_style: category_page_style.presence,
      }.compact.map { |setting_name, value| { setting_name:, value: } }
    end

    private

    def built_in_palettes_exist
      %i[light_palette_id dark_palette_id].each do |attribute|
        palette_id = public_send(attribute)
        next if palette_id.nil? || palette_id.positive?
        errors.add(attribute, :inclusion) if !ColorScheme::NAMES_TO_ID_MAP.value?(palette_id)
      end
    end
  end

  policy :current_user_is_admin
  model :theme
  policy :palettes_available_to_theme

  transaction do
    model :light_palette, :resolve_light_palette, optional: true
    model :dark_palette, :resolve_dark_palette, optional: true
    step :assign_theme_palettes
    only_if :enabling_built_in_palettes do
      step :offer_built_in_palettes
    end
    step :update_palette_selectability
  end

  step :update_site_settings
  step :expire_user_color_schemes_cache

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def fetch_theme(params:)
    Theme.find_by(id: params.theme_id)
  end

  def palettes_available_to_theme(params:, theme:)
    [params.light_palette_id, params.dark_palette_id].all? do |palette_id|
      palette_id.nil? || palette_id.negative? ||
        ColorScheme.where(id: palette_id, theme_id: [nil, theme.id]).exists?
    end
  end

  def resolve_light_palette(params:)
    DesignWizard::Action::ResolvePalette.call(palette_id: params.light_palette_id)
  end

  def resolve_dark_palette(params:)
    DesignWizard::Action::ResolvePalette.call(palette_id: params.dark_palette_id)
  end

  def assign_theme_palettes(theme:, light_palette:, dark_palette:)
    theme.update!(color_scheme_id: light_palette&.id, dark_color_scheme_id: dark_palette&.id)
  end

  def enabling_built_in_palettes(params:, theme:)
    params.palettes_user_selectable && ColorScheme.where(theme_id: theme.id).none?
  end

  def offer_built_in_palettes
    DesignWizard::PalettePairs::BUILT_IN_PAIRS.each do |pair|
      pair
        .values_at(:light, :dark)
        .compact
        .each do |name|
          DesignWizard::Action::ResolvePalette.call(palette_id: ColorScheme::NAMES_TO_ID_MAP[name])
        end
    end
  end

  def update_palette_selectability(params:, theme:)
    DesignWizard::Action::UpdatePaletteSelectability.call(
      theme:,
      selectable: params.palettes_user_selectable,
    )
  end

  # default_theme_id is hidden, so it has to be explicitly allowed.
  def update_site_settings(params:, theme:, guardian:)
    SiteSetting::Update.call(
      params: {
        settings: params.site_settings(theme_id: theme.id),
      },
      options: {
        allow_changing_hidden: %i[default_theme_id],
      },
      guardian:,
    ) { on_failure { fail!("failed to update site settings") } }
  end

  def expire_user_color_schemes_cache
    ApplicationSerializer.expire_cache_fragment!("user_color_schemes")
  end
end
