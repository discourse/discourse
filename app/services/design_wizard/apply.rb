# frozen_string_literal: true

# Applies the design choices made in the admin design wizard in one atomic
# operation: default theme, the theme's light/dark palettes, fonts, homepage
# and whether members can switch between the offered palettes.
class DesignWizard::Apply
  include Service::Base

  BASE_LIGHT_PALETTE_ID = ColorScheme::NAMES_TO_ID_MAP[ColorScheme::LIGHT_PALETTE_NAME]

  policy :current_user_is_admin

  params do
    attribute :theme_id, :integer
    attribute :light_palette_id, :integer
    attribute :dark_palette_id, :integer
    attribute :palettes_user_selectable, :boolean, default: false
    attribute :base_font, :string
    attribute :heading_font, :string
    attribute :default_text_size, :string
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
    validates :default_text_size,
              inclusion: {
                in: DefaultTextSizeSetting::DEFAULT_TEXT_SIZES,
              },
              allow_blank: true
    validates :homepage, inclusion: { in: %w[latest top hot categories] }, allow_blank: true
    validates :category_page_style,
              inclusion: {
                in: CategoryPageStyle.values.map { |style| style[:value] },
              },
              allow_blank: true
    validate :built_in_palettes_exist

    private

    def built_in_palettes_exist
      %i[light_palette_id dark_palette_id].each do |attribute|
        palette_id = public_send(attribute)
        next if palette_id.nil? || palette_id.positive?
        errors.add(attribute, :inclusion) if !ColorScheme::NAMES_TO_ID_MAP.value?(palette_id)
      end
    end
  end

  model :theme
  model :light_palette, :resolve_light_palette, optional: true
  model :dark_palette, :resolve_dark_palette, optional: true
  policy :palettes_available_to_theme

  transaction do
    step :set_default_theme
    step :assign_theme_palettes
    only_if :base_font_provided do
      step :update_base_font
    end
    only_if :heading_font_provided do
      step :update_heading_font
    end
    only_if :default_text_size_provided do
      step :update_default_text_size
    end
    only_if :homepage_provided do
      step :update_homepage
    end
    only_if :category_page_style_provided do
      step :update_category_page_style
    end
    only_if :enabling_built_in_palettes do
      step :materialize_built_in_palettes
    end
    step :update_palette_selectability
  end

  step :expire_user_color_schemes_cache

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def fetch_theme(params:)
    Theme.find_by(id: params.theme_id)
  end

  def resolve_light_palette(params:)
    DesignWizard::Action::ResolvePalette.call(palette_id: params.light_palette_id)
  end

  def resolve_dark_palette(params:)
    DesignWizard::Action::ResolvePalette.call(palette_id: params.dark_palette_id)
  end

  def palettes_available_to_theme(params:, theme:, light_palette:, dark_palette:)
    [
      [params.light_palette_id, light_palette],
      [params.dark_palette_id, dark_palette],
    ].all? do |palette_id, palette|
      palette_id.nil? || (palette.present? && [nil, theme.id].include?(palette.theme_id))
    end
  end

  def set_default_theme(theme:, guardian:)
    SiteSetting.set_and_log(:default_theme_id, theme.id, guardian.user)
  end

  def assign_theme_palettes(theme:, light_palette:, dark_palette:)
    theme.update!(color_scheme_id: light_palette&.id, dark_color_scheme_id: dark_palette&.id)
  end

  def base_font_provided(params:)
    params.base_font.present?
  end

  def update_base_font(params:, guardian:)
    SiteSetting.set_and_log(:base_font, params.base_font, guardian.user)
  end

  def heading_font_provided(params:)
    params.heading_font.present?
  end

  def update_heading_font(params:, guardian:)
    SiteSetting.set_and_log(:heading_font, params.heading_font, guardian.user)
  end

  def default_text_size_provided(params:)
    params.default_text_size.present?
  end

  def update_default_text_size(params:, guardian:)
    SiteSetting.set_and_log(:default_text_size, params.default_text_size, guardian.user)
  end

  def homepage_provided(params:)
    params.homepage.present?
  end

  def update_homepage(params:, guardian:)
    SiteSetting.set_and_log(:default_homepage, params.homepage, guardian.user)
  end

  def category_page_style_provided(params:)
    params.category_page_style.present?
  end

  def update_category_page_style(params:, guardian:)
    SiteSetting.set_and_log(:desktop_category_page_style, params.category_page_style, guardian.user)
  end

  def enabling_built_in_palettes(params:, theme:)
    params.palettes_user_selectable && ColorScheme.where(theme_id: theme.id).none?
  end

  def materialize_built_in_palettes
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
    offered = ColorScheme.where(theme_id: theme.id)
    offered = ColorScheme.where(via_wizard: true) if offered.none?

    ColorScheme
      .where(theme_id: Theme::CORE_THEMES.values)
      .or(ColorScheme.where(via_wizard: true))
      .where.not(id: offered.select(:id))
      .update_all(user_selectable: false)
    offered.update_all(user_selectable: params.palettes_user_selectable)
  end

  def expire_user_color_schemes_cache
    ApplicationSerializer.expire_cache_fragment!("user_color_schemes")
  end
end
