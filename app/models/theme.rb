require_dependency 'distributed_cache'
require_dependency 'stylesheet/compiler'
require_dependency 'stylesheet/manager'
require_dependency 'theme_settings_parser'
require_dependency 'theme_settings_manager'

class Theme < ActiveRecord::Base

  @cache = DistributedCache.new('theme')

  belongs_to :user
  belongs_to :color_scheme
  has_many :theme_fields, dependent: :destroy
  has_many :theme_settings, dependent: :destroy
  has_many :child_theme_relation, class_name: 'ChildTheme', foreign_key: 'parent_theme_id', dependent: :destroy
  has_many :child_themes, through: :child_theme_relation, source: :child_theme
  has_many :color_schemes
  belongs_to :remote_theme

  before_create do
    self.key ||= SecureRandom.uuid
    true
  end

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

    @dependant_themes = nil
    @included_themes = nil

    remove_from_cache!
    clear_cached_settings!
    notify_scheme_change if saved_change_to_color_scheme_id?
  end

  after_destroy do
    remove_from_cache!
    clear_cached_settings!
    if SiteSetting.default_theme_key == self.key
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
  end

  after_commit ->(theme) do
    theme.notify_theme_change
  end, on: :update

  def self.theme_keys
    if keys = @cache["theme_keys"]
      return keys
    end
    @cache["theme_keys"] = Set.new(Theme.pluck(:key))
  end

  def self.user_theme_keys
    if keys = @cache["user_theme_keys"]
      return keys
    end
    @cache["user_theme_keys"] = Set.new(
      Theme
      .where('user_selectable OR key = ?', SiteSetting.default_theme_key)
      .pluck(:key)
    )
  end

  def self.expire_site_cache!
    Site.clear_anon_cache!
    ApplicationSerializer.expire_cache_fragment!("user_themes")
  end

  def self.clear_default!
    SiteSetting.default_theme_key = ""
    expire_site_cache!
  end

  def set_default!
    SiteSetting.default_theme_key = key
    Theme.expire_site_cache!
  end

  def default?
    SiteSetting.default_theme_key == key
  end

  def self.lookup_field(key, target, field)
    return if key.blank?

    cache_key = "#{key}:#{target}:#{field}:#{ThemeField::COMPILER_VERSION}"
    lookup = @cache[cache_key]
    return lookup.html_safe if lookup

    target = target.to_sym
    theme = find_by(key: key)

    val = theme.resolve_baked_field(target, field) if theme

    (@cache[cache_key] = val || "").html_safe
  end

  def self.remove_from_cache!(themes = nil)
    clear_cache!
  end

  def self.clear_cache!
    @cache.clear
  end

  def self.targets
    @targets ||= Enum.new(common: 0, desktop: 1, mobile: 2, settings: 3)
  end

  def self.lookup_target(target_id)
    self.targets.invert[target_id]
  end

  def notify_scheme_change(clear_manager_cache = true)
    Stylesheet::Manager.cache.clear if clear_manager_cache
    message = refresh_message_for_targets(["desktop", "mobile", "admin"], self)
    MessageBus.publish('/file-change', message)
  end

  def notify_theme_change
    Stylesheet::Manager.clear_theme_cache!

    themes = [self] + dependant_themes

    message = themes.map do |theme|
      refresh_message_for_targets([:mobile_theme, :desktop_theme], theme)
    end.compact.flatten
    MessageBus.publish('/file-change', message)
  end

  def refresh_message_for_targets(targets, theme)
    targets.map do |target|
      href = Stylesheet::Manager.stylesheet_href(target.to_sym, theme.key)
      if href
        {
          target: target,
          new_href: href,
          theme_key: theme.key
        }
      end
    end
  end

  def dependant_themes
    @dependant_themes ||= resolve_dependant_themes(:up)
  end

  def included_themes
    @included_themes ||= resolve_dependant_themes(:down)
  end

  def resolve_dependant_themes(direction)

    select_field, where_field = nil

    if direction == :up
      select_field = "parent_theme_id"
      where_field = "child_theme_id"
    elsif direction == :down
      select_field = "child_theme_id"
      where_field = "parent_theme_id"
    else
      raise "Unknown direction"
    end

    themes = []
    return [] unless id

    uniq = Set.new
    uniq << id

    iterations = 0
    added = [id]

    while added.length > 0 && iterations < 5

      iterations += 1

      new_themes = Theme.where("id in (SELECT #{select_field}
                                  FROM child_themes
                                  WHERE #{where_field} in (?))", added).to_a

      added = []
      new_themes.each do |theme|
        unless uniq.include?(theme.id)
          added << theme.id
          uniq << theme.id
          themes << theme
        end
      end

    end

    themes
  end

  def resolve_baked_field(target, name)
    list_baked_fields(target, name).map { |f| f.value_baked || f.value }.join("\n")
  end

  def list_baked_fields(target, name)

    target = target.to_sym

    theme_ids = [self.id] + (included_themes.map(&:id) || [])
    fields = ThemeField.where(target_id: [Theme.targets[target], Theme.targets[:common]])
      .where(name: name.to_s)
      .includes(:theme)
      .joins("
        JOIN (
          SELECT #{theme_ids.map.with_index { |id, idx| "#{id} AS theme_id, #{idx} AS sort_column" }.join(" UNION ALL SELECT ")}
        ) as X ON X.theme_id = theme_fields.theme_id"
      )
      .order('sort_column, target_id')

    fields.each(&:ensure_baked!)
    fields
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

    type_id ||= type ? ThemeField.types[type.to_sym] : ThemeField.guess_type(name)
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
    else
      theme_fields.build(target_id: target_id, value: value, name: name, type_id: type_id, upload_id: upload_id) if value.present? || upload_id.present?
    end
  end

  def all_theme_variables
    fields = {}
    ([self] + (included_themes || [])).each do |theme|
      theme&.theme_fields.each do |field|
        next unless ThemeField.theme_var_type_ids.include?(field.type_id)
        next if fields.key?(field.name)
        fields[field.name] = field
      end
    end
    fields.values
  end

  def add_child_theme!(theme)
    child_theme_relation.create!(child_theme_id: theme.id)
    @included_themes = nil
    child_themes.reload
    save!
  end

  def settings
    field = theme_fields.where(target_id: Theme.targets[:settings], name: "yaml").first
    return [] unless field && field.error.nil?

    settings = []
    ThemeSettingsParser.new(field).load do |name, default, type, opts|
      settings << ThemeSettingsManager.create(name, default, type, self, opts)
    end
    settings
  end

  def cached_settings
    Rails.cache.fetch("settings_for_theme_#{self.key}", expires_in: 30.minutes) do
      hash = {}
      self.settings.each do |setting|
        hash[setting.name] = setting.value
      end
      hash
    end
  end

  def clear_cached_settings!
    Rails.cache.delete("settings_for_theme_#{self.key}")
  end

  def included_settings
    hash = {}

    self.included_themes.each do |theme|
      hash.merge!(theme.cached_settings)
    end

    hash.merge!(self.cached_settings)
    hash
  end

  def self.settings_for_client(key)
    theme = Theme.find_by(key: key)
    return {}.to_json unless theme

    theme.included_settings.to_json
  end

  def update_setting(setting_name, new_value)
    target_setting = settings.find { |setting| setting.name == setting_name }
    raise Discourse::NotFound unless target_setting

    target_setting.value = new_value
  end
end

# == Schema Information
#
# Table name: themes
#
#  id               :integer          not null, primary key
#  name             :string           not null
#  user_id          :integer          not null
#  key              :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  compiler_version :integer          default(0), not null
#  user_selectable  :boolean          default(FALSE), not null
#  hidden           :boolean          default(FALSE), not null
#  color_scheme_id  :integer
#  remote_theme_id  :integer
#
# Indexes
#
#  index_themes_on_key              (key)
#  index_themes_on_remote_theme_id  (remote_theme_id) UNIQUE
#
