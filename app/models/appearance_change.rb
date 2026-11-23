# frozen_string_literal: true

# A change to a site's appearance that is saved without going live, so it can
# be previewed first, then made live and switched back. It is one of:
#
# - palettes: a new light and dark palette for an existing theme
# - existing_palettes: a light and dark palette the site already has, for an
#   existing theme
# - theme: a new theme with its own new palettes, and optionally styles
# - installed_theme: a theme installed from the list of popular themes, with
#   whatever palettes it comes with
# - existing_theme: a theme the site already has, made the default as it is
# - component: a component holding styles for a theme the site keeps, such
#   as Horizon, and optionally new palettes for that theme. It's saved
#   disabled, previewed with `?preview_component_ids=`, and made live by
#   enabling it, which disables the theme's earlier ones.
#
# A new theme can be a new version of a theme an earlier change created. It is
# saved as "Name (draft)"; making it live renames the version it replaces to
# "Name (previous)", for an instant switch back, and removes older versions.
#
# The fonts it sets apply when it goes live. A theme's styles are typed (see
# AppearanceStyles::Policy); the CSS written from them is kept here and in the
# theme's common SCSS, so edits made to the theme by hand can be noticed.
class AppearanceChange < ActiveRecord::Base
  # the site-wide settings a change can set when it goes live
  SITE_SETTING_NAMES = %w[base_font heading_font].freeze
  # drafts that never go live are removed after this long
  DRAFT_LIFETIME = 7.days
  # marks previous_state recorded by an activation that hasn't finished
  PENDING_KEY = "pending"
  # marks previous_state while switching back hasn't finished
  REVERTING_KEY = "reverting"

  enum :kind,
       {
         palettes: 0,
         theme: 1,
         existing_palettes: 2,
         installed_theme: 3,
         existing_theme: 4,
         component: 5,
       },
       prefix: true

  belongs_to :theme
  belongs_to :light_color_scheme, class_name: "ColorScheme", optional: true
  belongs_to :dark_color_scheme, class_name: "ColorScheme", optional: true
  belongs_to :user, optional: true
  belongs_to :replaces_theme, class_name: "Theme", optional: true
  # the theme a component change's component is attached to
  belongs_to :parent_theme, class_name: "Theme", optional: true

  validates :name, presence: true, length: { maximum: 100 }
  validate :only_supported_site_settings

  scope :drafts, -> { where(activated_at: nil) }
  scope :abandoned_drafts, -> { drafts.where(updated_at: ...DRAFT_LIFETIME.ago) }

  def self.dark_palette_name(name)
    I18n.t("appearance_changes.dark_palette_name", name:, locale: SiteSetting.default_locale)
  end

  # "Name (draft)" or "Name (previous)"
  def self.version_name(name, version)
    I18n.t("appearance_changes.#{version}_name", name:, locale: SiteSetting.default_locale)
  end

  # Whether a new version can replace a theme: it was created by an
  # appearance change, nobody has changed it since, and users can't have
  # chosen it.
  def self.replaceable?(theme)
    theme.present? && !theme.user_selectable && managed_theme_ids.include?(theme.id)
  end

  # Themes and components created by appearance changes that nobody has
  # added files or components to since, so all they hold is their palettes
  # and the styles the change wrote.
  def self.managed_theme_ids
    managed_new_theme_ids + managed_component_ids
  end

  def self.managed_component_ids
    kind_component.includes(theme: :theme_fields).select(&:theme_unchanged?).map(&:theme_id).uniq
  end

  def self.managed_new_theme_ids
    kind_theme
      .where.not(
        ThemeField
          .where("theme_fields.theme_id = appearance_changes.theme_id")
          .where.not(<<~SQL, common: Theme.targets[:common])
            appearance_changes.css <> ''
            AND theme_fields.target_id = :common
            AND theme_fields.name = 'scss'
            AND theme_fields.value = appearance_changes.css
          SQL
          .arel
          .exists,
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

  def styled?
    css.present?
  end

  # Whether a new theme still holds only what the change put in it: no
  # components, and no files except the styles it wrote.
  def theme_unchanged?
    return attached_to_parent? && only_generated_styles? if kind_component?
    return true if !kind_theme?

    only_generated_styles? && theme.child_theme_relation.none?
  end

  # A component change's component is still attached to its theme.
  def attached_to_parent?
    ChildTheme.exists?(parent_theme_id:, child_theme_id: theme_id)
  end

  # The theme whose palettes the change sets: a component change's theme, or
  # the change's own theme.
  def palette_theme
    kind_component? ? parent_theme : theme
  end

  # Whether making the change live gives a theme new palettes. A component
  # change only does when it comes with palettes.
  def assigns_palettes?
    return false if new_default_theme?
    !kind_component? || light_color_scheme_id.present?
  end

  # The earlier components of the same theme, made by appearance changes,
  # that are enabled now. Making this one live disables them.
  def enabled_sibling_components
    return Theme.none if !kind_component?

    Theme.where(
      id: AppearanceChange.kind_component.where(parent_theme_id:).where.not(id:).select(:theme_id),
      enabled: true,
    ).where(id: ChildTheme.where(parent_theme_id:).select(:child_theme_id))
  end

  # Whether the change goes live by making its theme the default, rather
  # than by giving an existing theme new palettes.
  def new_default_theme?
    kind_theme? || kind_installed_theme? || kind_existing_theme?
  end

  # Whether the change created its theme, so the theme can go with it.
  def created_theme?
    kind_theme? || kind_installed_theme? || kind_component?
  end

  # An installed or existing theme uses whatever palettes it has, if any.
  def palettes_exist?
    return true if kind_installed_theme? || kind_existing_theme?
    return true if kind_component? && light_color_scheme_id.nil? && dark_color_scheme_id.nil?
    light_color_scheme.present? && dark_color_scheme.present?
  end

  # A font-bearing change must have gone live and still match the site's
  # fonts, even when its theme or palettes were already in use.
  def applied?
    if site_settings.present?
      return false if previous_state.blank? || activation_pending?
      return false if !site_settings.all? { |name, value| SiteSetting.get(name) == value }
    end
    return theme.default? if new_default_theme?
    return false if kind_component? && !(theme.enabled? && attached_to_parent?)
    return true if !assigns_palettes?

    palette_theme.color_scheme_id == light_color_scheme_id &&
      palette_theme.dark_color_scheme_id == dark_color_scheme_id
  end

  # The site settings making the change live sets: its fonts and, for a new
  # or installed theme, the default theme.
  def activation_site_settings
    return site_settings if !new_default_theme?

    site_settings.merge("default_theme_id" => theme_id)
  end

  # What making the change live replaces, so switching back can restore it.
  # When an earlier attempt applied the site settings but didn't finish, the
  # site already shows them, so the state recorded before that attempt is
  # used instead.
  def replaced_state
    if retrying_activation? || revert_interrupted?
      return previous_state.except(PENDING_KEY, REVERTING_KEY)
    end

    state = {
      "site_settings" =>
        activation_site_settings.keys.index_with { |setting_name| SiteSetting.get(setting_name) },
    }
    if (kind_theme? || kind_component?) && replaces_theme
      state["theme_names"] = {
        theme_id.to_s => theme.name,
        replaces_theme_id.to_s => replaces_theme.name,
      }
    end
    state["enabled_component_ids"] = enabled_sibling_components.pluck(:id) if kind_component?
    return state if !assigns_palettes?

    state.merge(
      "color_scheme_id" => palette_theme.color_scheme_id,
      "dark_color_scheme_id" => palette_theme.dark_color_scheme_id,
    )
  end

  # Recorded before the site settings change, so a retry after a later
  # failure still knows what they were.
  def record_pending_activation!(state)
    update!(previous_state: state.merge(PENDING_KEY => true))
  end

  def activation_pending?
    previous_state[PENDING_KEY] == true
  end

  # Marked before switching back restores the site settings, so a failure
  # after that still lets switching back, or going live again, finish.
  def record_pending_revert!
    update!(previous_state: previous_state.merge(REVERTING_KEY => true))
  end

  # Switching back restored the site settings but didn't finish.
  def revert_interrupted?
    previous_state[REVERTING_KEY] == true &&
      previous_state["site_settings"].to_h.all? do |name, value|
        SiteSetting.get(name).to_s == value.to_s
      end
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
      theme.destroy! if created_theme? && disposable_theme?
      created_palettes.each { |palette| palette.destroy! if disposable_palette?(palette) }
    end
  end

  # Once this change's theme is live, keeps the version it replaced as
  # "Name (previous)" and removes the one before that, so a theme has at most
  # a live, a previous and a draft version.
  def replace_previous_version!
    return if replaces_theme.nil?

    transaction do
      replaces_theme.update!(name: self.class.version_name(name, :previous))
      theme.update!(name:)

      previous = AppearanceChange.where(kind:).find_by(theme_id: replaces_theme_id)
      older = previous&.replaces_theme
      # the previous version's own switch back to the older one is dropped
      # below, but another change may still need it
      if older.nil? || older.default? || (older.component? && older.enabled?) ||
           self.class.switch_back_target?(older, except: [previous.id])
        next
      end

      # the previous version can't switch back to the older one any more
      previous.update!(replaces_theme_id: nil, previous_state: {})
      AppearanceChange.where(kind:, theme_id: older.id).find_each(&:discard_version!)
    end
  end

  # The themes making this change live renames or removes: the version it
  # replaces, and the one before that.
  def versions_changed_on_activation
    return [] if !(kind_theme? || kind_component?) || replaces_theme.nil?

    previous = AppearanceChange.where(kind:).find_by(theme_id: replaces_theme_id)
    [replaces_theme, previous&.replaces_theme].compact
  end

  # Whether switching back from some change would make this theme live again.
  def self.switch_back_target?(theme, except: [])
    where
      .not(id: except)
      .where(
        "previous_state -> 'site_settings' ->> 'default_theme_id' = :id OR previous_state -> 'enabled_component_ids' @> :ids::jsonb",
        id: theme.id.to_s,
        ids: [theme.id].to_json,
      )
      .exists?
  end

  # Removes an old version's change, theme and the palettes nothing else uses.
  # A theme someone has changed or let users choose since stays as an
  # ordinary theme.
  def discard_version!
    transaction do
      destroy!
      theme.destroy! if !live_theme? && !theme.user_selectable? && theme_unchanged?
      created_palettes.each { |palette| palette.destroy! if disposable_palette?(palette) }
    end
  end

  private

  # A default theme, or an enabled component, is in use.
  def live_theme?
    theme.component? ? theme.enabled? : theme.default?
  end

  def retrying_activation?
    activation_pending? &&
      activation_site_settings.all? { |name, value| SiteSetting.get(name).to_s == value.to_s }
  end

  # Palettes the site already had aren't the change's to remove, and an
  # installed theme's palettes go with the theme when it's removed.
  def created_palettes
    kind_existing_palettes? || kind_installed_theme? || kind_existing_theme? ? [] : palettes
  end

  def only_supported_site_settings
    errors.add(:site_settings, :invalid) if (site_settings.keys - SITE_SETTING_NAMES).present?
  end

  def only_generated_styles?
    theme.theme_fields.all? { |field| generated_styles?(field) }
  end

  def generated_styles?(field)
    styled? && field.target_id == Theme.targets[:common] && field.name == "scss" &&
      field.value == css
  end

  # Anything edited since the change was saved belongs to whoever edited it.
  def edited_since_saved?(record)
    record.updated_at > created_at
  end

  # Another change may still use the theme, such as one made later to make
  # an installed theme live.
  def disposable_theme?
    !edited_since_saved?(theme) && !live_theme? && !theme.user_selectable? && theme_unchanged? &&
      AppearanceChange.where(theme_id:).where.not(id:).none? &&
      !AppearanceChange.switch_back_target?(theme)
  end

  def disposable_palette?(palette)
    !edited_since_saved?(palette) && !palette.user_selectable? &&
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
#  css                   :text             default(""), not null
#  kind                  :integer          not null
#  name                  :string           not null
#  previous_state        :jsonb            not null
#  site_settings         :jsonb            not null
#  styles                :jsonb            not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  dark_color_scheme_id  :integer
#  light_color_scheme_id :integer
#  parent_theme_id       :integer
#  replaces_theme_id     :integer
#  theme_id              :integer          not null
#  user_id               :integer          not null
#
# Indexes
#
#  index_appearance_changes_on_parent_theme_id  (parent_theme_id)
#  index_appearance_changes_on_theme_id         (theme_id)
#
