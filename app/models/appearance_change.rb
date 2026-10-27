# frozen_string_literal: true

# A change to a site's appearance that is saved without going live, so it can
# be previewed first, then made live and switched back. It is one of:
#
# - palettes: a new light and dark palette for an existing theme
# - existing_palettes: a light and dark palette the site already has, for an
#   existing theme
# - theme: a new theme with its own new palettes
#
# The fonts it sets apply when it goes live.
class AppearanceChange < ActiveRecord::Base
  # the site-wide settings a change can set when it goes live
  SITE_SETTING_NAMES = %w[base_font heading_font].freeze
  # drafts that never go live are removed after this long
  DRAFT_LIFETIME = 7.days

  enum :kind, { palettes: 0, theme: 1, existing_palettes: 2 }, prefix: true

  belongs_to :theme
  belongs_to :light_color_scheme, class_name: "ColorScheme", optional: true
  belongs_to :dark_color_scheme, class_name: "ColorScheme", optional: true
  belongs_to :user, optional: true

  validates :name, presence: true, length: { maximum: 100 }
  validate :only_supported_site_settings

  scope :drafts, -> { where(activated_at: nil) }
  scope :abandoned_drafts, -> { drafts.where(created_at: ...DRAFT_LIFETIME.ago) }

  def self.dark_palette_name(name)
    I18n.t("appearance_changes.dark_palette_name", name:, locale: SiteSetting.default_locale)
  end

  # Themes created by appearance changes that nobody has added files or
  # components to since, so all they hold is their palettes.
  def self.palette_only_theme_ids
    kind_theme
      .where.not(
        ThemeField.where("theme_fields.theme_id = appearance_changes.theme_id").arel.exists,
      )
      .where.not(
        ChildTheme.where("child_themes.parent_theme_id = appearance_changes.theme_id").arel.exists,
      )
      .distinct
      .pluck(:theme_id)
  end

  def draft?
    activated_at.nil?
  end

  def palettes
    [light_color_scheme, dark_color_scheme].compact
  end

  def palettes_exist?
    light_color_scheme.present? && dark_color_scheme.present?
  end

  # Whether the site uses the change now: the new theme is the default, or the
  # palettes are the theme's.
  def applied?
    return theme.default? if kind_theme?

    theme.color_scheme_id == light_color_scheme_id &&
      theme.dark_color_scheme_id == dark_color_scheme_id
  end

  # The site settings making the change live sets: its fonts and, for a new
  # theme, the default theme.
  def activation_site_settings
    return site_settings if !kind_theme?

    site_settings.merge("default_theme_id" => theme_id)
  end

  # What making the change live replaces, so switching back can restore it.
  def replaced_state
    state = {
      "site_settings" =>
        activation_site_settings.keys.index_with { |setting_name| SiteSetting.get(setting_name) },
    }
    return state if kind_theme?

    state.merge(
      "color_scheme_id" => theme.color_scheme_id,
      "dark_color_scheme_id" => theme.dark_color_scheme_id,
    )
  end

  # Whether the palettes and the default theme that switching back restores
  # still exist.
  def restorable?
    palette_ids = previous_state.values_at("color_scheme_id", "dark_color_scheme_id").compact.uniq
    return false if ColorScheme.unscoped.where(id: palette_ids).count != palette_ids.size

    default_theme_id = previous_state.dig("site_settings", "default_theme_id")
    default_theme_id.nil? || Theme.exists?(id: default_theme_id, component: false)
  end

  # Removes the change along with the theme and palettes it created. Any of
  # them that someone has started using or editing stays as an ordinary theme
  # or palette.
  def discard!
    transaction do
      destroy!
      theme.destroy! if kind_theme? && disposable_theme?
      created_palettes.each { |palette| palette.destroy! if disposable_palette?(palette) }
    end
  end

  private

  # Palettes the site already had aren't the change's to remove.
  def created_palettes
    kind_existing_palettes? ? [] : palettes
  end

  def only_supported_site_settings
    errors.add(:site_settings, :invalid) if (site_settings.keys - SITE_SETTING_NAMES).present?
  end

  def disposable_theme?
    !theme.default? && !theme.user_selectable? && theme.theme_fields.none? &&
      theme.child_theme_relation.none? &&
      AppearanceChange.where(
        "previous_state -> 'site_settings' ->> 'default_theme_id' = ?",
        theme.id.to_s,
      ).none?
  end

  def disposable_palette?(palette)
    !palette.user_selectable? &&
      Theme.where("color_scheme_id = :id OR dark_color_scheme_id = :id", id: palette.id).none? &&
      AppearanceChange.where(
        "previous_state ->> 'color_scheme_id' = :id OR previous_state ->> 'dark_color_scheme_id' = :id",
        id: palette.id.to_s,
      ).none?
  end
end

# == Schema Information
#
# Table name: appearance_changes
#
#  id                    :bigint           not null, primary key
#  activated_at          :datetime
#  kind                  :integer          not null
#  name                  :string           not null
#  previous_state        :jsonb            not null
#  site_settings         :jsonb            not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  dark_color_scheme_id  :integer          not null
#  light_color_scheme_id :integer          not null
#  theme_id              :integer          not null
#  user_id               :integer          not null
#
# Indexes
#
#  index_appearance_changes_on_theme_id  (theme_id)
#
