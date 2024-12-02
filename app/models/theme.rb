# frozen_string_literal: true

require "csv"
require "json_schemer"

class Theme < ActiveRecord::Base
  include GlobalPath

  BASE_COMPILER_VERSION = 85

  class SettingsMigrationError < StandardError
  end

  attr_accessor :child_components
  attr_accessor :skip_child_components_update

  def self.cache
    @cache ||= DistributedCache.new("theme:compiler:#{BASE_COMPILER_VERSION}")
  end

  belongs_to :user
  belongs_to :color_scheme
  has_many :theme_fields, dependent: :destroy, validate: false
  has_many :theme_settings, dependent: :destroy
  has_many :theme_translation_overrides, dependent: :destroy
  has_many :child_theme_relation,
           class_name: "ChildTheme",
           foreign_key: "parent_theme_id",
           dependent: :destroy
  has_many :parent_theme_relation,
           class_name: "ChildTheme",
           foreign_key: "child_theme_id",
           dependent: :destroy
  has_many :child_themes, -> { order(:name) }, through: :child_theme_relation, source: :child_theme
  has_many :parent_themes,
           -> { order(:name) },
           through: :parent_theme_relation,
           source: :parent_theme
  has_many :color_schemes
  has_many :theme_settings_migrations
  belongs_to :remote_theme, dependent: :destroy
  has_one :theme_modifier_set, dependent: :destroy
  has_one :theme_svg_sprite, dependent: :destroy

  has_one :settings_field,
          -> { where(target_id: Theme.targets[:settings], name: "yaml") },
          class_name: "ThemeField"
  has_one :javascript_cache, dependent: :destroy
  has_many :locale_fields,
           -> { filter_locale_fields(I18n.fallbacks[I18n.locale]) },
           class_name: "ThemeField"
  has_many :upload_fields,
           -> { where(type_id: ThemeField.types[:theme_upload_var]).preload(:upload) },
           class_name: "ThemeField"
  has_many :extra_scss_fields,
           -> { where(target_id: Theme.targets[:extra_scss]) },
           class_name: "ThemeField"
  has_many :yaml_theme_fields,
           -> { where("name = 'yaml' AND type_id = ?", ThemeField.types[:yaml]) },
           class_name: "ThemeField"
  has_many :var_theme_fields,
           -> { where("type_id IN (?)", ThemeField.theme_var_type_ids) },
           class_name: "ThemeField"
  has_many :builder_theme_fields,
           -> { where("name IN (?)", ThemeField.scss_fields) },
           class_name: "ThemeField"
  has_many :migration_fields,
           -> { where(target_id: Theme.targets[:migrations]) },
           class_name: "ThemeField"

  validate :component_validations
  validate :validate_theme_fields

  after_create :update_child_components

  scope :user_selectable, -> { where("user_selectable OR id = ?", SiteSetting.default_theme_id) }

  scope :include_relations,
        -> do
          includes(
            :child_themes,
            :parent_themes,
            :remote_theme,
            :theme_settings,
            :settings_field,
            :locale_fields,
            :user,
            :color_scheme,
            :theme_translation_overrides,
            theme_fields: %i[upload theme_settings_migration],
          )
        end

  delegate :remote_url, to: :remote_theme, private: true, allow_nil: true

  def notify_color_change(color, scheme: nil)
    scheme ||= color.color_scheme
    changed_colors << color if color
    changed_schemes << scheme if scheme
  end

  def theme_modifier_set
    super || build_theme_modifier_set
  end

  after_save do
    changed_colors.each(&:save!)
    changed_schemes.each(&:save!)

    changed_colors.clear
    changed_schemes.clear

    any_non_css_fields_changed =
      changed_fields.any? { |f| !(f.basic_scss_field? || f.extra_scss_field?) }

    changed_fields.each(&:save!)
    changed_fields.clear

    theme_modifier_set.save!

    theme_fields.select(&:basic_html_field?).each(&:invalidate_baked!) if saved_change_to_name?

    if saved_change_to_color_scheme_id? || saved_change_to_user_selectable? || saved_change_to_name?
      Theme.expire_site_cache!
    end
    notify_with_scheme = saved_change_to_color_scheme_id?

    reload
    settings_field&.ensure_baked! # Other fields require setting to be **baked**
    theme_fields.each(&:ensure_baked!)

    update_javascript_cache!

    remove_from_cache!
    ColorScheme.hex_cache.clear

    notify_theme_change(with_scheme: notify_with_scheme)

    if theme_setting_requests_refresh
      DB.after_commit do
        Discourse.request_refresh!
        self.theme_setting_requests_refresh = false
      end
    end

    if any_non_css_fields_changed && should_refresh_development_clients?
      MessageBus.publish "/file-change", ["development-mode-theme-changed"]
    end
  end

  def should_refresh_development_clients?
    Rails.env.development?
  end

  def update_child_components
    if !component? && child_components.present? && !skip_child_components_update
      child_components.each do |url|
        url = ThemeStore::GitImporter.new(url.strip).url
        theme = RemoteTheme.find_by(remote_url: url)&.theme
        theme ||= RemoteTheme.import_theme(url, user)
        child_themes << theme
      end
    end
  end

  def update_javascript_cache!
    all_extra_js =
      theme_fields
        .where(target_id: Theme.targets[:extra_js])
        .order(:name, :id)
        .pluck(:name, :value)
        .to_h

    if all_extra_js.present?
      js_compiler = ThemeJavascriptCompiler.new(id, name)
      js_compiler.append_tree(all_extra_js)
      settings_hash = build_settings_hash

      js_compiler.prepend_settings(settings_hash) if settings_hash.present?

      javascript_cache || build_javascript_cache
      javascript_cache.update!(content: js_compiler.content, source_map: js_compiler.source_map)
    else
      javascript_cache&.destroy!
    end
  end

  after_destroy do
    remove_from_cache!
    Theme.clear_default! if SiteSetting.default_theme_id == self.id

    if self.id
      ColorScheme
        .where(theme_id: self.id)
        .where("id NOT IN (SELECT color_scheme_id FROM themes where color_scheme_id IS NOT NULL)")
        .destroy_all

      ColorScheme.where(theme_id: self.id).update_all(theme_id: nil)
    end

    Theme.expire_site_cache!
  end

  def self.compiler_version
    get_set_cache "compiler_version" do
      dependencies = [
        BASE_COMPILER_VERSION,
        EmberCli.ember_version,
        GlobalSetting.cdn_url,
        GlobalSetting.s3_cdn_url,
        GlobalSetting.s3_endpoint,
        GlobalSetting.s3_bucket,
        Discourse.current_hostname,
      ]
      Digest::SHA1.hexdigest(dependencies.join)
    end
  end

  def self.get_set_cache(key, &blk)
    cache.defer_get_set(key, &blk)
  end

  def self.theme_ids
    get_set_cache "theme_ids" do
      Theme.pluck(:id)
    end
  end

  def self.parent_theme_ids
    get_set_cache "parent_theme_ids" do
      Theme.where(component: false).pluck(:id)
    end
  end

  def self.is_parent_theme?(id)
    self.parent_theme_ids.include?(id)
  end

  def self.user_theme_ids
    get_set_cache "user_theme_ids" do
      Theme.user_selectable.pluck(:id)
    end
  end

  def self.enabled_theme_and_component_ids
    get_set_cache "enabled_theme_and_component_ids" do
      theme_ids = Theme.user_selectable.where(enabled: true).pluck(:id)
      component_ids =
        ChildTheme
          .where(parent_theme_id: theme_ids)
          .joins(:child_theme)
          .where(themes: { enabled: true })
          .pluck(:child_theme_id)
      (theme_ids | component_ids)
    end
  end

  def self.allowed_remote_theme_ids
    return nil if GlobalSetting.allowed_theme_repos.blank?

    get_set_cache "allowed_remote_theme_ids" do
      urls = GlobalSetting.allowed_theme_repos.split(",").map(&:strip)
      Theme.joins(:remote_theme).where("remote_themes.remote_url in (?)", urls).pluck(:id)
    end
  end

  def self.components_for(theme_id)
    get_set_cache "theme_components_for_#{theme_id}" do
      ChildTheme.where(parent_theme_id: theme_id).pluck(:child_theme_id)
    end
  end

  def self.expire_site_cache!
    Site.clear_anon_cache!
    clear_cache!
    ApplicationSerializer.expire_cache_fragment!("user_themes")
    ColorScheme.hex_cache.clear
    CSP::Extension.clear_theme_extensions_cache!
    SvgSprite.expire_cache
  end

  def self.clear_default!
    SiteSetting.default_theme_id = -1
    expire_site_cache!
  end

  def self.transform_ids(id)
    return [] if id.blank?
    id = id.to_i

    get_set_cache "transformed_ids_#{id}" do
      all_ids =
        if self.is_parent_theme?(id)
          components = components_for(id).tap { |c| c.sort!.uniq! }
          [id, *components]
        else
          [id]
        end

      disabled_ids =
        Theme
          .where(id: all_ids)
          .includes(:remote_theme)
          .select { |t| !t.supported? || !t.enabled? }
          .map(&:id)

      all_ids - disabled_ids
    end
  end

  def set_default!
    if component
      raise Discourse::InvalidParameters.new(I18n.t("themes.errors.component_no_default"))
    end
    SiteSetting.default_theme_id = id
    Theme.expire_site_cache!
  end

  def default?
    SiteSetting.default_theme_id == id
  end

  def supported?
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

  def validate_theme_fields
    theme_fields.each do |field|
      field.errors.full_messages.each { |message| errors.add(:base, message) } unless field.valid?
    end
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
      self.enabled = true
      self.component = false
      ChildTheme.where("child_theme_id = ?", id).destroy_all
      self.save!
    end
  end

  def self.lookup_field(theme_id, target, field, skip_transformation: false, csp_nonce: nil)
    return "" if theme_id.blank?

    theme_ids = !skip_transformation ? transform_ids(theme_id) : [theme_id]
    resolved = (resolve_baked_field(theme_ids, target.to_sym, field) || "")
    resolved = resolved.gsub(ThemeField::CSP_NONCE_PLACEHOLDER, csp_nonce) if csp_nonce
    resolved.html_safe
  end

  def self.lookup_modifier(theme_ids, modifier_name)
    theme_ids = [theme_ids] unless theme_ids.is_a?(Array)

    get_set_cache("#{theme_ids.join(",")}:modifier:#{modifier_name}:#{Theme.compiler_version}") do
      ThemeModifierSet.resolve_modifier_for_themes(theme_ids, modifier_name)
    end
  end

  def self.remove_from_cache!
    clear_cache!
  end

  def self.clear_cache!
    cache.clear
  end

  def self.targets
    @targets ||=
      Enum.new(
        common: 0,
        desktop: 1,
        mobile: 2,
        settings: 3,
        translations: 4,
        extra_scss: 5,
        extra_js: 6,
        tests_js: 7,
        migrations: 8,
      )
  end

  def self.lookup_target(target_id)
    self.targets.invert[target_id]
  end

  def self.notify_theme_change(
    theme_ids,
    with_scheme: false,
    clear_manager_cache: true,
    all_themes: false
  )
    Stylesheet::Manager.clear_theme_cache!
    targets = %i[mobile_theme desktop_theme]

    if with_scheme
      targets.prepend(:desktop, :mobile, :admin)
      targets.append(*Discourse.find_plugin_css_assets(mobile_view: true, desktop_view: true))
      Stylesheet::Manager.cache.clear if clear_manager_cache
    end

    if all_themes
      message = theme_ids.map { |id| refresh_message_for_targets(targets, id) }.flatten
    else
      message = refresh_message_for_targets(targets, theme_ids).flatten
    end

    MessageBus.publish("/file-change", message)
  end

  def notify_theme_change(with_scheme: false)
    DB.after_commit do
      theme_ids = Theme.transform_ids(id)
      self.class.notify_theme_change(theme_ids, with_scheme: with_scheme)
    end
  end

  def self.refresh_message_for_targets(targets, theme_ids)
    theme_ids = [theme_ids] unless theme_ids.is_a?(Array)

    targets.each_with_object([]) do |target, data|
      theme_ids.each do |theme_id|
        data << Stylesheet::Manager.new(theme_id: theme_id).stylesheet_data(target.to_sym)
      end
    end
  end

  def self.resolve_baked_field(theme_ids, target, name)
    target = target.to_sym
    name = name&.to_sym

    target = :mobile if target == :mobile_theme
    target = :desktop if target == :desktop_theme

    case target
    when :extra_js
      get_set_cache("#{theme_ids.join(",")}:extra_js:#{Theme.compiler_version}") do
        require_rebake =
          ThemeField.where(theme_id: theme_ids, target_id: Theme.targets[:extra_js]).where(
            "compiler_version <> ?",
            Theme.compiler_version,
          )

        ActiveRecord::Base.transaction do
          require_rebake.each { |tf| tf.ensure_baked! }

          Theme.where(id: require_rebake.map(&:theme_id)).each(&:update_javascript_cache!)
        end

        caches =
          JavascriptCache
            .where(theme_id: theme_ids)
            .index_by(&:theme_id)
            .values_at(*theme_ids)
            .compact

        caches.map { |c| <<~HTML.html_safe }.join("\n")
          <script defer src="#{c.url}" data-theme-id="#{c.theme_id}" nonce="#{ThemeField::CSP_NONCE_PLACEHOLDER}"></script>
        HTML
      end
    when :translations
      theme_field_values(theme_ids, :translations, I18n.fallbacks[name])
        .to_a
        .select(&:second)
        .uniq { |((theme_id, _, _), _)| theme_id }
        .flat_map(&:second)
        .join("\n")
    else
      theme_field_values(theme_ids, [:common, target], name).values.compact.flatten.join("\n")
    end
  end

  def self.theme_field_values(theme_ids, targets, names)
    cache.defer_get_set_bulk(
      Array(theme_ids).product(Array(targets), Array(names)),
      lambda do |(theme_id, target, name)|
        "#{theme_id}:#{target}:#{name}:#{Theme.compiler_version}"
      end,
    ) do |keys|
      keys = keys.map { |theme_id, target, name| [theme_id, Theme.targets[target], name.to_s] }

      keys
        .map do |theme_id, target_id, name|
          ThemeField.where(theme_id: theme_id, target_id: target_id, name: name)
        end
        .inject { |a, b| a.or(b) }
        .each(&:ensure_baked!)
        .map { |tf| [[tf.theme_id, tf.target_id, tf.name], tf.value_baked || tf.value] }
        .group_by(&:first)
        .transform_values { |x| x.map(&:second) }
        .values_at(*keys)
    end
  end

  def self.list_baked_fields(theme_ids, target, name)
    target = target.to_sym
    name = name&.to_sym

    if target == :translations
      fields = ThemeField.find_first_locale_fields(theme_ids, I18n.fallbacks[name])
    else
      target = :mobile if target == :mobile_theme
      target = :desktop if target == :desktop_theme
      fields =
        ThemeField.find_by_theme_ids(theme_ids).where(
          target_id: [Theme.targets[target], Theme.targets[:common]],
        )
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
    theme_ids = Theme.transform_ids(id)
    theme_ids = [theme_ids.first] if name != :color_definitions
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

  def changed_schemes
    @changed_schemes ||= Set.new
  end

  def set_field(target:, name:, value: nil, type: nil, type_id: nil, upload_id: nil)
    name = name.to_s

    target_id = Theme.targets[target.to_sym]
    raise "Unknown target #{target} passed to set field" unless target_id

    type_id ||=
      type ? ThemeField.types[type.to_sym] : ThemeField.guess_type(name: name, target: target)
    raise "Unknown type #{type} passed to set field" unless type_id

    value ||= ""

    field = theme_fields.find_by(name: name, target_id: target_id, type_id: type_id)

    if field
      if value.blank? && !upload_id
        field.destroy
      else
        if field.value != value || field.upload_id != upload_id
          field.value = value
          field.upload_id = upload_id
          changed_fields << field
        end
      end
    else
      if value.present? || upload_id.present?
        field =
          theme_fields.build(
            target_id: target_id,
            value: value,
            name: name,
            type_id: type_id,
            upload_id: upload_id,
          )
        changed_fields << field
      end
    end
    field
  end

  def child_theme_ids=(theme_ids)
    super(theme_ids)
    Theme.clear_cache!
  end

  def parent_theme_ids=(theme_ids)
    super(theme_ids)
    Theme.clear_cache!
  end

  def add_relative_theme!(kind, theme)
    new_relation =
      if kind == :child
        child_theme_relation.new(child_theme_id: theme.id)
      else
        parent_theme_relation.new(parent_theme_id: theme.id)
      end
    if new_relation.save
      child_themes.reload
      parent_themes.reload
      save!
      Theme.clear_cache!
    else
      raise Discourse::InvalidParameters.new(new_relation.errors.full_messages.join(", "))
    end
  end

  def internal_translations
    @internal_translations ||= translations(internal: true)
  end

  def translations(internal: false)
    fallbacks = I18n.fallbacks[I18n.locale]
    begin
      data =
        locale_fields.first&.translation_data(
          with_overrides: false,
          internal: internal,
          fallback_fields: locale_fields,
        )
      return {} if data.nil?
      best_translations = {}
      fallbacks.reverse.each { |locale| best_translations.deep_merge! data[locale] if data[locale] }
      ThemeTranslationManager.list_from_hash(
        theme: self,
        hash: best_translations,
        locale: I18n.locale,
      )
    rescue ThemeTranslationParser::InvalidYaml
      {}
    end
  end

  def settings
    field = settings_field
    settings = {}

    if field && field.error.nil?
      ThemeSettingsParser
        .new(field)
        .load do |name, default, type, opts|
          settings[name] = ThemeSettingsManager.create(name, default, type, self, opts)
        end
    end

    settings
  end

  def cached_settings
    Theme.get_set_cache "settings_for_theme_#{self.id}" do
      build_settings_hash
    end
  end

  def cached_default_settings
    Theme.get_set_cache "default_settings_for_theme_#{self.id}" do
      settings_hash = {}
      self.settings.each { |name, setting| settings_hash[name] = setting.default }

      theme_uploads = build_theme_uploads_hash
      settings_hash["theme_uploads"] = theme_uploads if theme_uploads.present?

      theme_uploads_local = build_local_theme_uploads_hash
      settings_hash["theme_uploads_local"] = theme_uploads_local if theme_uploads_local.present?

      settings_hash
    end
  end

  def build_settings_hash
    hash = {}
    self.settings.each { |name, setting| hash[name] = setting.value }

    theme_uploads = build_theme_uploads_hash
    hash["theme_uploads"] = theme_uploads if theme_uploads.present?

    theme_uploads_local = build_local_theme_uploads_hash
    hash["theme_uploads_local"] = theme_uploads_local if theme_uploads_local.present?

    hash
  end

  def build_theme_uploads_hash
    hash = {}
    upload_fields
      .includes(:javascript_cache, :upload)
      .each do |field|
        hash[field.name] = Discourse.store.cdn_url(field.upload.url) if field.upload&.url
      end
    hash
  end

  def build_local_theme_uploads_hash
    hash = {}
    upload_fields
      .includes(:javascript_cache, :upload)
      .each do |field|
        hash[field.name] = field.javascript_cache.local_url if field.javascript_cache
      end
    hash
  end

  # Retrieves a theme setting
  #
  # @param setting_name [String, Symbol] The name of the setting to retrieve.
  #
  # @return [Object] The value of the setting that matches the provided name.
  #
  # @raise [Discourse::NotFound] If no setting is found with the provided name.
  #
  # @example
  #   theme.get_setting("some_boolean") => True
  #   theme.get_setting("some_string") => "hello"
  #   theme.get_setting(:some_boolean) => True
  #   theme.get_setting(:some_string) => "hello"
  #
  def get_setting(setting_name)
    target_setting = settings[setting_name.to_sym]
    raise Discourse::NotFound unless target_setting
    target_setting.value
  end

  def update_setting(setting_name, new_value)
    target_setting = settings[setting_name.to_sym]
    raise Discourse::NotFound unless target_setting
    target_setting.value = new_value
    self.theme_setting_requests_refresh = true if target_setting.requests_refresh?
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
      path[0..-2].each { |key| cursor = (cursor[key] ||= {}) }
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
        theme_fields
          .where(type_id: ThemeField.types[:theme_upload_var])
          .each { |field| hash[field.name] = field.file_path }
      end

      meta[:color_schemes] = {}.tap do |hash|
        schemes = self.color_schemes
        # The selected color scheme may not belong to the theme, so include it anyway
        schemes = [self.color_scheme] + schemes if self.color_scheme
        schemes.uniq.each do |scheme|
          hash[scheme.name] = {}.tap do |colors|
            scheme.colors.each { |color| colors[color.name] = color.hex }
          end
        end
      end

      meta[:modifiers] = {}.tap do |hash|
        ThemeModifierSet.modifiers.keys.each do |modifier|
          value = self.theme_modifier_set.public_send(modifier)
          hash[modifier] = value if !value.nil?
        end
      end

      meta[
        :learn_more
      ] = "https://meta.discourse.org/t/beginners-guide-to-using-discourse-themes/91966"
    end
  end

  def disabled_by
    find_disable_action_log&.acting_user
  end

  def disabled_at
    find_disable_action_log&.created_at
  end

  def with_scss_load_paths
    return yield([]) if self.extra_scss_fields.empty?

    ThemeStore::ZipExporter
      .new(self)
      .with_export_dir(extra_scss_only: true) { |dir| yield ["#{dir}/stylesheets"] }
  end

  def scss_variables
    settings_hash = build_settings_hash
    theme_variable_fields = var_theme_fields

    return if theme_variable_fields.empty? && settings_hash.empty?

    contents = +""

    theme_variable_fields&.each do |field|
      if field.type_id == ThemeField.types[:theme_upload_var]
        if upload = field.upload
          url = upload_cdn_path(upload.url)
          contents << "$#{field.name}: unquote(\"#{url}\");"
        else
          contents << "$#{field.name}: unquote(\"\");"
        end
      else
        contents << to_scss_variable(field.name, field.value)
      end
    end

    settings_hash&.each do |name, value|
      next if name == "theme_uploads" || name == "theme_uploads_local"
      contents << to_scss_variable(name, value)
    end

    contents
  end

  def migrate_settings(start_transaction: true, fields: nil, allow_out_of_sequence_migration: false)
    block = ->(*) do
      runner = ThemeSettingsMigrationsRunner.new(self)
      results =
        runner.run(fields:, raise_error_on_out_of_sequence: !allow_out_of_sequence_migration)

      next if results.blank?

      old_settings = self.theme_settings.pluck(:name)
      self.theme_settings.destroy_all

      final_result = results.last

      final_result[:settings_after].each do |key, val|
        self.update_setting(key.to_sym, val)
      rescue Discourse::NotFound
        if old_settings.include?(key)
          final_result[:settings_after].delete(key)
        else
          raise Theme::SettingsMigrationError.new(
                  I18n.t(
                    "themes.import_error.migrations.unknown_setting_returned_by_migration",
                    name: final_result[:original_name],
                    setting_name: key,
                  ),
                )
        end
      end

      results.each do |res|
        record =
          ThemeSettingsMigration.new(
            theme_id: self.id,
            version: res[:version],
            name: res[:name],
            theme_field_id: res[:theme_field_id],
          )

        record.calculate_diff(res[:settings_before], res[:settings_after])

        # If out of sequence migration is allowed we don't want to raise an error if the record is invalid due to version
        # conflicts
        allow_out_of_sequence_migration ? record.save : record.save!
      end

      self.reload
      self.update_javascript_cache!
    end

    if start_transaction
      self.transaction(&block)
    else
      block.call
    end
  end

  def convert_list_to_json_schema(setting_row, setting)
    schema = setting.json_schema
    return if !schema
    keys = schema["items"]["properties"].keys
    return if !keys

    current_values = CSV.parse(setting_row.value, **{ col_sep: "|" }).flatten

    new_values =
      current_values.map do |item|
        parts = CSV.parse(item, **{ col_sep: "," }).flatten
        raise "Schema validation failed" if keys.size < parts.size
        parts.zip(keys).map(&:reverse).to_h
      end

    schemer = JSONSchemer.schema(schema)
    raise "Schema validation failed" if !schemer.valid?(new_values)

    setting_row.value = new_values.to_json
    setting_row.data_type = setting.type
    setting_row.save!
  end

  def baked_js_tests_with_digest
    tests_tree =
      theme_fields_to_tree(
        theme_fields.where(target_id: Theme.targets[:tests_js]).order(name: :asc),
      )

    return nil, nil if tests_tree.blank?

    migrations_tree =
      theme_fields_to_tree(
        theme_fields.where(target_id: Theme.targets[:migrations]).order(name: :asc),
      )

    compiler = ThemeJavascriptCompiler.new(id, name, minify: false)
    compiler.append_tree(migrations_tree, include_variables: false)
    compiler.append_tree(tests_tree)

    compiler.append_raw_script "test_setup.js", <<~JS
      (function() {
        require("discourse/lib/theme-settings-store").registerSettings(#{self.id}, #{cached_default_settings.to_json}, { force: true });
      })();
    JS

    content = compiler.content

    if compiler.source_map
      content +=
        "\n//# sourceMappingURL=data:application/json;base64,#{Base64.strict_encode64(compiler.source_map)}\n"
    end

    [content, Digest::SHA1.hexdigest(content)]
  end

  def repository_url
    return unless remote_url
    remote_url.gsub(
      %r{([^@]+@)?(http(s)?://)?(?<host>[^:/]+)[:/](?<path>((?!\.git).)*)(\.git)?(?<rest>.*)},
      '\k<host>/\k<path>\k<rest>',
    )
  end

  def user_selectable_count
    UserOption.where(theme_ids: [id]).count
  end

  private

  attr_accessor :theme_setting_requests_refresh

  def theme_fields_to_tree(theme_fields_scope)
    theme_fields_scope.reduce({}) do |tree, theme_field|
      tree[theme_field.file_path] = theme_field.value
      tree
    end
  end

  def to_scss_variable(name, value)
    escaped = SassC::Script::Value::String.quote(value.to_s, sass: true)
    "$#{name}: unquote(#{escaped});"
  end

  def find_disable_action_log
    if component? && !enabled?
      @disable_log ||=
        UserHistory
          .where(context: id.to_s, action: UserHistory.actions[:disable_theme_component])
          .order("created_at DESC")
          .first
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
#  enabled          :boolean          default(TRUE), not null
#  auto_update      :boolean          default(TRUE), not null
#
# Indexes
#
#  index_themes_on_remote_theme_id  (remote_theme_id) UNIQUE
#
