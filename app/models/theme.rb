# frozen_string_literal: true

require_dependency 'distributed_cache'
require_dependency 'stylesheet/compiler'
require_dependency 'stylesheet/manager'
require_dependency 'theme_settings_parser'
require_dependency 'theme_settings_manager'
require_dependency 'theme_translation_parser'
require_dependency 'theme_translation_manager'

class Theme < ActiveRecord::Base

  @cache = DistributedCache.get('theme')

  belongs_to :user
  belongs_to :color_scheme
  has_many :theme_fields, dependent: :destroy
  has_many :theme_settings, dependent: :destroy
  has_many :theme_translation_overrides, dependent: :destroy
  has_many :child_theme_relation, class_name: 'ChildTheme', foreign_key: 'parent_theme_id', dependent: :destroy
  has_many :parent_theme_relation, class_name: 'ChildTheme', foreign_key: 'child_theme_id', dependent: :destroy
  has_many :child_themes, -> { order(:name) }, through: :child_theme_relation, source: :child_theme
  has_many :parent_themes, -> { order(:name) }, through: :parent_theme_relation, source: :parent_theme
  has_many :color_schemes
  belongs_to :remote_theme, autosave: true

  has_one :settings_field, -> { where(target_id: Theme.targets[:settings], name: "yaml") }, class_name: 'ThemeField'
  has_many :locale_fields, -> { filter_locale_fields(I18n.fallbacks[I18n.locale]) }, class_name: 'ThemeField'

  validate :component_validations

  scope :user_selectable, ->() {
    where('user_selectable OR id = ?', SiteSetting.default_theme_id)
  }

  def notify_color_change(color)
    changed_colors << color
  end

  after_save do
    color_schemes = {}
    changed_colors.each do |color|
      color.save!
      color_schemes[color.color_scheme_id] ||= color.color_scheme
    end

    color_schemes.values.each(&:save!)

    changed_colors.clear

    changed_fields.each(&:save!)
    changed_fields.clear

    Theme.expire_site_cache! if saved_change_to_user_selectable? || saved_change_to_name?
    notify_with_scheme = saved_change_to_color_scheme_id?

    reload
    settings_field&.ensure_baked! # Other fields require setting to be **baked**
    theme_fields.each(&:ensure_baked!)

    remove_from_cache!
    clear_cached_settings!
    ColorScheme.hex_cache.clear
    notify_theme_change(with_scheme: notify_with_scheme)
  end

  after_destroy do
    remove_from_cache!
    clear_cached_settings!
    if SiteSetting.default_theme_id == self.id
      Theme.clear_default!
    end

    if self.id
      ColorScheme
        .where(theme_id: self.id)
        .where("id NOT IN (SELECT color_scheme_id FROM themes where color_scheme_id IS NOT NULL)")
        .destroy_all

      ColorScheme
        .where(theme_id: self.id)
        .update_all(theme_id: nil)
    end

    Theme.expire_site_cache!
    ColorScheme.hex_cache.clear
    CSP::Extension.clear_theme_extensions_cache!
    SvgSprite.expire_cache
  end

  def self.get_set_cache(key, &blk)
    if val = @cache[key]
      return val
    end
    @cache[key] = blk.call
  end

  def self.theme_ids
    get_set_cache "theme_ids" do
      Theme.pluck(:id)
    end
  end

  def self.user_theme_ids
    get_set_cache "user_theme_ids" do
      Theme.user_selectable.pluck(:id)
    end
  end

  def self.components_for(theme_id)
    get_set_cache "theme_components_for_#{theme_id}" do
      ChildTheme.where(parent_theme_id: theme_id).distinct.pluck(:child_theme_id)
    end
  end

  def self.expire_site_cache!
    Site.clear_anon_cache!
    clear_cache!
    ApplicationSerializer.expire_cache_fragment!("user_themes")
    ColorScheme.hex_cache.clear
  end

  def self.clear_default!
    SiteSetting.default_theme_id = -1
    expire_site_cache!
  end

  def self.transform_ids(ids, extend: true)
    return [] if ids.nil?
    get_set_cache "#{extend ? "extended_" : ""}transformed_ids_#{ids.join("_")}" do
      next [] if ids.blank?

      ids = ids.dup
      ids.uniq!
      parent = ids.shift

      components = ids
      components.push(*components_for(parent)) if extend
      components.sort!.uniq!

      all_ids = [parent, *components]

      disabled_ids = Theme.where(id: all_ids).includes(:remote_theme)
        .reject(&:enabled?).pluck(:id)

      all_ids - disabled_ids
    end
  end

  def set_default!
    if component
      raise Discourse::InvalidParameters.new(
        I18n.t("themes.errors.component_no_default")
      )
    end
    SiteSetting.default_theme_id = id
    Theme.expire_site_cache!
  end

  def default?
    SiteSetting.default_theme_id == id
  end

  def enabled?
    if minimum_version = remote_theme&.minimum_discourse_version
      return false unless Discourse.has_needed_version?(Discourse::VERSION::STRING, minimum_version)
    end

    if maximum_version = remote_theme&.maximum_discourse_version
      return false unless Discourse.has_needed_version?(maximum_version, Discourse::VERSION::STRING)
    end

    true
  end

  def component_validations
    return unless component

    errors.add(:base, I18n.t("themes.errors.component_no_color_scheme")) if color_scheme_id.present?
    errors.add(:base, I18n.t("themes.errors.component_no_user_selectable")) if user_selectable
    errors.add(:base, I18n.t("themes.errors.component_no_default")) if default?
  end

  def switch_to_component!
    return if component

    Theme.transaction do
      self.component = true

      self.color_scheme_id = nil
      self.user_selectable = false
      Theme.clear_default! if default?

      ChildTheme.where("parent_theme_id = ?", id).destroy_all
      self.save!
    end
  end

  def switch_to_theme!
    return unless component

    Theme.transaction do
      self.component = false
      ChildTheme.where("child_theme_id = ?", id).destroy_all
      self.save!
    end
  end

  def self.lookup_field(theme_ids, target, field)
    return if theme_ids.blank?
    theme_ids = [theme_ids] unless Array === theme_ids

    theme_ids = transform_ids(theme_ids)
    cache_key = "#{theme_ids.join(",")}:#{target}:#{field}:#{ThemeField::COMPILER_VERSION}"
    lookup = @cache[cache_key]
    return lookup.html_safe if lookup

    target = target.to_sym
    val = resolve_baked_field(theme_ids, target, field)

    (@cache[cache_key] = val || "").html_safe
  end

  def self.remove_from_cache!
    clear_cache!
  end

  def self.clear_cache!
    @cache.clear
  end

  def self.targets
    @targets ||= Enum.new(common: 0, desktop: 1, mobile: 2, settings: 3, translations: 4, extra_scss: 5)
  end

  def self.lookup_target(target_id)
    self.targets.invert[target_id]
  end

  def self.notify_theme_change(theme_ids, with_scheme: false, clear_manager_cache: true, all_themes: false)
    Stylesheet::Manager.clear_theme_cache!
    targets = [:mobile_theme, :desktop_theme]

    if with_scheme
      targets.prepend(:desktop, :mobile, :admin)
      Stylesheet::Manager.cache.clear if clear_manager_cache
    end

    if all_themes
      message = theme_ids.map { |id| refresh_message_for_targets(targets, id) }.flatten
    else
      parent_ids = Theme.where(id: theme_ids).joins(:parent_themes).pluck(:parent_theme_id).uniq
      message = refresh_message_for_targets(targets, theme_ids | parent_ids).flatten
    end

    MessageBus.publish('/file-change', message)
  end

  def notify_theme_change(with_scheme: false)
    theme_ids = Theme.transform_ids([id])
    self.class.notify_theme_change(theme_ids, with_scheme: with_scheme)
  end

  def self.refresh_message_for_targets(targets, theme_ids)
    targets.map do |target|
      Stylesheet::Manager.stylesheet_data(target.to_sym, theme_ids)
    end
  end

  def self.resolve_baked_field(theme_ids, target, name)
    list_baked_fields(theme_ids, target, name).map { |f| f.value_baked || f.value }.join("\n")
  end

  def self.list_baked_fields(theme_ids, target, name)
    target = target.to_sym
    name = name&.to_sym

    if target == :translations
      fields = ThemeField.find_first_locale_fields(theme_ids, I18n.fallbacks[name])
    else
      fields = ThemeField.find_by_theme_ids(theme_ids)
        .where(target_id: [Theme.targets[target], Theme.targets[:common]])
      fields = fields.where(name: name.to_s) unless name.nil?
      fields = fields.order(:target_id)
    end

    fields.each(&:ensure_baked!)
    fields
  end

  def resolve_baked_field(target, name)
    list_baked_fields(target, name).map { |f| f.value_baked || f.value }.join("\n")
  end

  def list_baked_fields(target, name)
    theme_ids = Theme.transform_ids([id])
    self.class.list_baked_fields(theme_ids, target, name)
  end

  def remove_from_cache!
    self.class.remove_from_cache!
  end

  def changed_fields
    @changed_fields ||= []
  end

  def changed_colors
    @changed_colors ||= []
  end

  def set_field(target:, name:, value: nil, type: nil, type_id: nil, upload_id: nil)
    name = name.to_s

    target_id = Theme.targets[target.to_sym]
    raise "Unknown target #{target} passed to set field" unless target_id

    type_id ||= type ? ThemeField.types[type.to_sym] : ThemeField.guess_type(name: name, target: target)
    raise "Unknown type #{type} passed to set field" unless type_id

    value ||= ""

    field = theme_fields.find { |f| f.name == name && f.target_id == target_id && f.type_id == type_id }
    if field
      if value.blank? && !upload_id
        theme_fields.delete field.destroy
      else
        if field.value != value || field.upload_id != upload_id
          field.value = value
          field.upload_id = upload_id
          changed_fields << field
        end
      end
      field
    else
      theme_fields.build(target_id: target_id, value: value, name: name, type_id: type_id, upload_id: upload_id) if value.present? || upload_id.present?
    end
  end

  def all_theme_variables
    fields = {}
    ids = Theme.transform_ids([id])
    ThemeField.find_by_theme_ids(ids).where(type_id: ThemeField.theme_var_type_ids).each do |field|
      next if fields.key?(field.name)
      fields[field.name] = field
    end
    fields.values
  end

  def add_child_theme!(theme)
    new_relation = child_theme_relation.new(child_theme_id: theme.id)
    if new_relation.save
      child_themes.reload
      save!
      Theme.clear_cache!
    else
      raise Discourse::InvalidParameters.new(new_relation.errors.full_messages.join(", "))
    end
  end

  def internal_translations
    translations(internal: true)
  end

  def translations(internal: false)
    fallbacks = I18n.fallbacks[I18n.locale]
    begin
      data = locale_fields.first&.translation_data(with_overrides: false, internal: internal, fallback_fields: locale_fields)
      return {} if data.nil?
      best_translations = {}
      fallbacks.reverse.each do |locale|
        best_translations.deep_merge! data[locale] if data[locale]
      end
      ThemeTranslationManager.list_from_hash(theme: self, hash: best_translations, locale: I18n.locale)
    rescue ThemeTranslationParser::InvalidYaml
      {}
    end
  end

  def settings
    field = settings_field
    return [] unless field && field.error.nil?

    settings = []
    ThemeSettingsParser.new(field).load do |name, default, type, opts|
      settings << ThemeSettingsManager.create(name, default, type, self, opts)
    end
    settings
  end

  def cached_settings
    Rails.cache.fetch("settings_for_theme_#{self.id}", expires_in: 30.minutes) do
      hash = {}
      self.settings.each do |setting|
        hash[setting.name] = setting.value
      end
      hash
    end
  end

  def clear_cached_settings!
    Rails.cache.delete("settings_for_theme_#{self.id}")
  end

  def included_settings
    hash = {}

    Theme.where(id: Theme.transform_ids([id])).each do |theme|
      hash.merge!(theme.cached_settings)
    end

    hash.merge!(self.cached_settings)
    hash
  end

  def update_setting(setting_name, new_value)
    target_setting = settings.find { |setting| setting.name == setting_name }
    raise Discourse::NotFound unless target_setting

    target_setting.value = new_value
  end

  def update_translation(translation_key, new_value)
    target_translation = translations.find { |translation| translation.key == translation_key }
    raise Discourse::NotFound unless target_translation
    target_translation.value = new_value
  end

  def translation_override_hash
    hash = {}
    theme_translation_overrides.each do |override|
      cursor = hash
      path = [override.locale] + override.translation_key.split(".")
      path[0..-2].each do |key|
        cursor = (cursor[key] ||= {})
      end
      cursor[path[-1]] = override.value
    end
    hash
  end

  def generate_metadata_hash
    {}.tap do |meta|
      meta[:name] = name
      meta[:component] = component

      RemoteTheme::METADATA_PROPERTIES.each do |property|
        meta[property] = remote_theme&.public_send(property)
        meta[property] = nil if meta[property] == "URL" # Clean up old discourse_theme CLI placeholders
      end

      meta[:assets] = {}.tap do |hash|
        theme_fields.where(type_id: ThemeField.types[:theme_upload_var]).each do |field|
          hash[field.name] = field.file_path
        end
      end

      meta[:color_schemes] = {}.tap do |hash|
        schemes = self.color_schemes
        # The selected color scheme may not belong to the theme, so include it anyway
        schemes = [self.color_scheme] + schemes if self.color_scheme
        schemes.uniq.each do |scheme|
          hash[scheme.name] = {}.tap { |colors| scheme.colors.each { |color| colors[color.name] = color.hex } }
        end
      end

      meta[:learn_more] = "https://meta.discourse.org/t/beginners-guide-to-using-discourse-themes/91966"

    end
  end
end

# == Schema Information
#
# Table name: themes
#
#  id               :integer          not null, primary key
#  name             :string           not null
#  user_id          :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  compiler_version :integer          default(0), not null
#  user_selectable  :boolean          default(FALSE), not null
#  hidden           :boolean          default(FALSE), not null
#  color_scheme_id  :integer
#  remote_theme_id  :integer
#  component        :boolean          default(FALSE), not null
#
# Indexes
#
#  index_themes_on_remote_theme_id  (remote_theme_id) UNIQUE
#
