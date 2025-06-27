# frozen_string_literal: true

module SiteSettingExtension
  include SiteSettings::DeprecatedSettings
  include HasSanitizableFields

  SiteSettingChangeResult = Struct.new(:previous_value, :new_value)
  InvalidSettingAccess = Class.new(StandardError)

  delegate :description, :keywords, :placeholder, :humanized_name, to: SiteSettings::LabelFormatter

  # support default_locale being set via global settings
  # this also adds support for testing the extension and global settings
  # for site locale
  def self.extended(klass)
    if GlobalSetting.respond_to?(:default_locale) && GlobalSetting.default_locale.present?
      # protected
      klass.send :setup_shadowed_methods, :default_locale, GlobalSetting.default_locale
    end
  end

  # we need a default here to support defaults per locale
  def default_locale=(val)
    val = val.to_s
    raise Discourse::InvalidParameters.new(:value) unless LocaleSiteSetting.valid_value?(val)
    if val != self.default_locale
      add_override!(:default_locale, val)
      refresh!
      Discourse.request_refresh!
    end
  end

  def default_locale?
    true
  end

  # set up some sort of default so we can look stuff up
  def default_locale
    # note optimised cause this is called a lot so avoiding .presence which
    # adds 2 method calls
    locale = current[:default_locale]
    if locale && !locale.blank?
      locale
    else
      SiteSettings::DefaultsProvider::DEFAULT_LOCALE
    end
  end

  def has_setting?(v)
    defaults.has_setting?(v)
  end

  def supported_types
    SiteSettings::TypeSupervisor.supported_types
  end

  def types
    SiteSettings::TypeSupervisor.types
  end

  def listen_for_changes=(val)
    @listen_for_changes = val
  end

  def provider=(val)
    @provider = val
    refresh!
  end

  def provider
    @provider ||= SiteSettings::DbProvider.new(SiteSetting)
  end

  def mutex
    @mutex ||= Mutex.new
  end

  def current
    @containers ||= {}
    @containers[provider.current_site] ||= {}
  end

  def theme_site_settings
    @theme_site_settings ||= {}
    @theme_site_settings[provider.current_site] ||= {}
  end

  def defaults
    @defaults ||= SiteSettings::DefaultsProvider.new(self)
  end

  def type_supervisor
    @type_supervisor ||= SiteSettings::TypeSupervisor.new(defaults)
  end

  def categories
    @categories ||= {}
  end

  def themeable
    @themeable ||= {}
  end

  def areas
    @areas ||= {}
  end

  def mandatory_values
    @mandatory_values ||= {}
  end

  def shadowed_settings
    @shadowed_settings ||= Set.new
  end

  def requires_confirmation_settings
    @requires_confirmation_settings ||= {}
  end

  def hidden_settings_provider
    @hidden_settings_provider ||= SiteSettings::HiddenProvider.new
  end

  def hidden_settings
    hidden_settings_provider.all
  end

  def refresh_settings
    @refresh_settings ||= [:default_locale]
  end

  def client_settings
    @client_settings ||= [:default_locale]
  end

  def previews
    @previews ||= {}
  end

  def secret_settings
    @secret_settings ||= Set.new
  end

  def plugins
    @plugins ||= {}
  end

  def load_settings(file, plugin: nil)
    SiteSettings::YamlLoader
      .new(file)
      .load do |category, name, default, opts|
        setting(name, default, opts.merge(category: category, plugin: plugin))
      end
  end

  def deprecated_settings
    @deprecated_settings ||= SiteSettings::DeprecatedSettings::SETTINGS.map(&:first).to_set
  end

  def deprecated_setting_alias(setting_name)
    SiteSettings::DeprecatedSettings::SETTINGS
      .find { |setting| setting.second.to_s == setting_name.to_s }
      &.first
  end

  def theme_site_settings_json(theme_id)
    key = SiteSettingExtension.theme_site_settings_cache_key(theme_id)
    json =
      Discourse
        .cache
        .fetch(key, expires_in: 30.minutes) { theme_site_settings_json_uncached(theme_id) }
    Rails.logger.error("Nil theme_site_settings_json from the cache for '#{key}'") if json.nil?
    json || ""
  rescue => e
    Rails.logger.error("Error while retrieving theme_site_settings_json: #{e.message}")
    ""
  end

  def setting_metadata_hash(setting)
    setting_hash = {
      setting:,
      default: SiteSetting.defaults[setting].to_s,
      description: SiteSetting.description(setting),
      humanized_name: SiteSetting.humanized_name(setting),
    }.merge(type_supervisor.type_hash(setting))
  end

  def themeable_site_settings
    themeable.select { |_, value| value }.keys
  end

  def client_settings_json
    key = SiteSettingExtension.client_settings_cache_key
    json = Discourse.cache.fetch(key, expires_in: 30.minutes) { client_settings_json_uncached }
    Rails.logger.error("Nil client_settings_json from the cache for '#{key}'") if json.nil?
    json || ""
  rescue => e
    Rails.logger.error("Error while retrieving client_settings_json: #{e.message}")
    ""
  end

  def client_settings_json_uncached
    MultiJson.dump(
      Hash[
        *@client_settings
          .flat_map do |name|
            # Themeable site settings require a theme ID, which we do not always
            # have when loading client site settings. They are excluded here,
            # to get them use theme_site_settings_json(:theme_id)
            next if themeable[name]

            value =
              if deprecated_settings.include?(name.to_s)
                public_send(name, warn: false)
              else
                public_send(name)
              end

            type = type_supervisor.get_type(name)
            if type == :upload
              value = value.to_s
            elsif type == :uploaded_image_list
              value = value.map(&:to_s).join("|")
            end

            [name, value]
          end
          .compact
      ],
    )
  rescue => e
    Rails.logger.error("Error while generating client_settings_json_uncached: #{e.message}")
    nil
  end

  def theme_site_settings_json_uncached(theme_id)
    MultiJson.dump(theme_site_settings[theme_id])
  end

  # Retrieve all settings
  def all_settings(
    include_hidden: false,
    include_locale_setting: true,
    only_overridden: false,
    basic_attributes: false,
    filter_categories: nil,
    filter_plugin: nil,
    filter_names: nil,
    filter_allowed_hidden: nil,
    filter_area: nil
  )
    locale_setting_hash = {
      setting: "default_locale",
      humanized_name: humanized_name("default_locale"),
      default: SiteSettings::DefaultsProvider::DEFAULT_LOCALE,
      category: "required",
      description: description("default_locale"),
      type: SiteSetting.types[SiteSetting.types[:enum]],
      preview: nil,
      value: self.default_locale,
      valid_values: LocaleSiteSetting.values,
      translate_names: LocaleSiteSetting.translate_names?,
    }

    include_locale_setting = false if filter_categories.present? || filter_plugin.present?

    defaults
      .all(default_locale)
      .reject do |setting_name, _|
        plugins[name] && !Discourse.plugins_by_name[plugins[name]].configurable?
      end
      .select do |setting_name, _|
        is_hidden = hidden_settings.include?(setting_name)

        next true if !is_hidden
        next false if !include_hidden
        next true if filter_allowed_hidden.nil?

        filter_allowed_hidden.include?(setting_name)
      end
      .select do |setting_name, _|
        if filter_categories && filter_categories.any?
          filter_categories.include?(categories[setting_name])
        else
          true
        end
      end
      .select do |setting_name, _|
        if filter_area
          Array.wrap(areas[setting_name]).include?(filter_area)
        else
          true
        end
      end
      .select do |setting_name, _|
        if filter_plugin
          plugins[setting_name] == filter_plugin
        else
          true
        end
      end
      .reject do |setting_name, _|
        # Do not show themeable site settings all_settings list or in the UI, they
        # are managed separately via the ThemeSiteSetting model.
        themeable[setting_name]
      end
      .map do |s, v|
        type_hash = type_supervisor.type_hash(s)
        default = defaults.get(s, default_locale).to_s

        value = public_send(s)
        value = value.map(&:to_s).join("|") if type_hash[:type].to_s == "uploaded_image_list"

        if type_hash[:type].to_s == "upload" && default.to_i < Upload::SEEDED_ID_THRESHOLD
          default = default_uploads[default.to_i]
        end

        opts = {
          setting: s,
          humanized_name: humanized_name(s),
          description: description(s),
          keywords: keywords(s),
          category: categories[s],
          primary_area: areas[s]&.first,
        }

        if !basic_attributes
          opts.merge!(
            default: default,
            value: value.to_s,
            preview: previews[s],
            secret: secret_settings.include?(s),
            placeholder: placeholder(s),
            mandatory_values: mandatory_values[s],
            requires_confirmation: requires_confirmation_settings[s],
            themeable: themeable[s],
          )
          opts.merge!(type_hash)
        end

        opts[:plugin] = plugins[s] if plugins[s]

        opts
      end
      .select do |setting|
        if only_overridden
          setting[:value] != setting[:default]
        else
          true
        end
      end
      .select do |setting|
        if filter_names
          filter_names.include?(setting[:setting].to_s)
        else
          true
        end
      end
      .unshift(include_locale_setting && !only_overridden ? locale_setting_hash : nil)
      .compact
  end

  def self.client_settings_cache_key
    # NOTE: we use the git version in the key to ensure
    # that we don't end up caching the incorrect version
    # in cases where we are cycling unicorns
    "client_settings_json_#{Discourse.git_version}"
  end

  def self.theme_site_settings_cache_key(theme_id)
    # NOTE: we use the git version in the key to ensure
    # that we don't end up caching the incorrect version
    # in cases where we are cycling unicorns
    "theme_site_settings_json_#{theme_id}__#{Discourse.git_version}"
  end

  # Refresh all the site settings and theme site settings
  def refresh!(refresh_site_settings: true, refresh_theme_site_settings: true)
    mutex.synchronize do
      ensure_listen_for_changes

      if refresh_site_settings
        new_hash =
          Hash[
            *(
              provider
                .all
                .map do |s|
                  [s.name.to_sym, type_supervisor.to_rb_value(s.name, s.value, s.data_type)]
                end
                .to_a
                .flatten
            )
          ]

        defaults_view = defaults.all(new_hash[:default_locale])

        # add locale default and defaults based on default_locale, cause they are cached
        new_hash = defaults_view.merge!(new_hash)

        # add shadowed
        shadowed_settings.each { |ss| new_hash[ss] = GlobalSetting.public_send(ss) }

        changes, deletions = diff_hash(new_hash, current)

        changes.each { |name, val| current[name] = val }
        deletions.each { |name, _| current[name] = defaults_view[name] }
        uploads.clear
      end

      if refresh_theme_site_settings
        new_theme_site_settings = ThemeSiteSetting.generate_theme_map

        theme_site_setting_changes, theme_site_setting_deletions =
          diff_hash(new_theme_site_settings, theme_site_settings)
        theme_site_setting_changes.each do |theme_id, settings|
          theme_site_settings[theme_id] ||= {}
          theme_site_settings[theme_id].merge!(settings)
        end
        theme_site_setting_deletions.each { |theme_id, _| theme_site_settings.delete(theme_id) }
      end

      clear_cache!(
        expire_theme_site_setting_cache:
          ThemeSiteSetting.can_access_db? && refresh_theme_site_settings,
      )
    end
  end

  def ensure_listen_for_changes
    return if @listen_for_changes == false

    unless @subscribed
      MessageBus.subscribe("/site_settings") do |message|
        process_message(message) if message.data["process"] != process_id
      end

      @subscribed = true
    end
  end

  def process_message(message)
    begin
      MessageBus.on_connect.call(message.site_id)
      refresh!
    ensure
      MessageBus.on_disconnect.call(message.site_id)
    end
  end

  def process_id
    @process_id ||= SecureRandom.uuid
  end

  def after_fork
    @process_id = nil
    ensure_listen_for_changes
  end

  def raise_invalid_setting_access(setting_name)
    raise SiteSettingExtension::InvalidSettingAccess.new(
            "#{setting_name} cannot be changed like this because it is a themeable setting. Instead, use the ThemeSiteSettingManager service to manage themeable site settings.",
          )
  end

  ##
  # Removes an override for a setting, reverting it to the default value.
  # This method is only called manually usually, more often than not
  # setting overrides are removed in database migrations.
  #
  # Here we also handle notifying the UI of the change in the case
  # of theme site settings and clearing relevant caches, and triggering
  # server-side events for changed settings.
  #
  # Themeable site settings cannot be removed this way, they must be
  # changed via the ThemeSiteSetting model.
  #
  # @param name [Symbol] the name of the setting
  # @param val [Any] the value to set
  def remove_override!(name)
    raise_invalid_setting_access(name) if themeable[name]

    old_val = current[name]
    provider.destroy(name)
    current[name] = defaults.get(name, default_locale)

    return if current[name] == old_val

    clear_uploads_cache(name)
    clear_cache!
    if old_val != current[name]
      DiscourseEvent.trigger(:site_setting_changed, name, old_val, current[name])
    end
  end

  ##
  # Adds an override, which is to say a database entry for the setting
  # instead of using the default.
  #
  # The `set`, `set_and_log`, and `setting_name=` methods all call
  # this method. Its opposite is remove_override!.
  #
  # Here we also handle notifying the UI of the change in the case
  # of theme site settings and clearing relevant caches, and triggering
  # server-side events for changed settings.
  #
  # Themeable site settings cannot be changed this way, they must be
  # changed via the ThemeSiteSetting model.
  #
  # @param name [Symbol] the name of the setting
  # @param val [Any] the value to set
  #
  # @example
  #   SiteSetting.add_override!(:site_description, "My awesome forum")
  #
  # @raise [SiteSettingExtension::InvalidSettingAccess] if the setting is themeable
  #   (themeable settings must be changed via ThemeSiteSetting model)
  #
  # @note When called from the Rails console, this method automatically logs the change
  #   with the system user.
  #
  # @see remove_override! for removing an override and reverting to default value
  def add_override!(name, val)
    raise_invalid_setting_access(name) if themeable[name]

    old_val = current[name]
    val, type = type_supervisor.to_db_value(name, val)

    sanitize_override = val.is_a?(String) && client_settings.include?(name)

    sanitized_val = sanitize_override ? sanitize_field(val) : val

    if mandatory_values[name.to_sym]
      sanitized_val =
        (mandatory_values[name.to_sym].split("|") | sanitized_val.to_s.split("|")).join("|")
    end

    provider.save(name, sanitized_val, type)
    current[name] = type_supervisor.to_rb_value(name, sanitized_val)

    return if current[name] == old_val

    clear_uploads_cache(name)
    notify_clients!(name) if client_settings.include?(name)
    clear_cache!

    if defined?(Rails::Console)
      details = "Updated via Rails console"
      details = DiscoursePluginRegistry.apply_modifier(:site_setting_log_details, details)
      log(name, val, old_val, Discourse.system_user, details)
    end

    DiscourseEvent.trigger(:site_setting_changed, name, old_val, current[name])
  end

  # Updates a theme-specific site setting value in memory and notifies observers.
  #
  # This method is used to change site settings that are marked as "themeable",
  # which means they can have different values per theme. Unlike `add_override!`,
  # the database isn't touched here.
  #
  # @param theme_id [Integer] The ID of the theme to update the setting for
  # @param name [String, Symbol] The name of the site setting to change
  # @param val [Object] The new "ruby" value for the site setting
  #
  # @example
  #   SiteSetting.change_themeable_site_setting(5, "enable_welcome_banner", false)
  #
  # @note Unlike regular site settings which use add_override!, themeable settings
  #   should be changed via the ThemeSiteSettingManager service.
  #
  # @see ThemeSiteSettingManager service for the higher-level implementation that handles
  #   database persistence and logging.
  def change_themeable_site_setting(theme_id, name, val)
    name = name.to_sym

    theme_site_settings[theme_id] ||= {}
    old_val = theme_site_settings[theme_id][name]
    theme_site_settings[theme_id][name] = val

    notify_clients!(name, theme_id: theme_id) if client_settings.include?(name)

    clear_cache!(expire_theme_site_setting_cache: true)

    DiscourseEvent.trigger(:theme_site_setting_changed, name, old_val, val)
  end

  def notify_changed!
    MessageBus.publish("/site_settings", process: process_id)
  end

  def notify_clients!(name, scoped_to = nil)
    MessageBus.publish(
      "/client_settings",
      name: name,
      # default_locale is a special case, it is not themeable and we define
      # a custom getter for it, so we can just use the normal getter
      value:
        name.to_s == "default_locale" ? self.public_send(name) : self.public_send(name, scoped_to),
      scoped_to: scoped_to,
    )
  end

  def requires_refresh?(name)
    refresh_settings.include?(name.to_sym)
  end

  HOSTNAME_SETTINGS = %w[
    disabled_image_download_domains
    blocked_onebox_domains
    exclude_rel_nofollow_domains
    blocked_email_domains
    allowed_email_domains
    allowed_spam_host_domains
  ]

  def filter_value(name, value)
    if HOSTNAME_SETTINGS.include?(name)
      value
        .split("|")
        .map do |url|
          url.strip!
          get_hostname(url)
        end
        .compact
        .uniq
        .join("|")
    else
      value
    end
  end

  def set(name, value, options = nil)
    if has_setting?(name)
      raise_invalid_setting_access(name) if themeable[name]

      value = filter_value(name, value)
      if options
        self.public_send("#{name}=", value, options)
      else
        self.public_send("#{name}=", value)
      end
      Discourse.request_refresh! if requires_refresh?(name)
    else
      raise Discourse::InvalidParameters.new(
              "Either no setting named '#{name}' exists or value provided is invalid",
            )
    end
  end

  def set_and_log(name, value, user = Discourse.system_user, detailed_message = nil)
    if has_setting?(name)
      raise_invalid_setting_access(name) if themeable[name]

      prev_value = public_send(name)
      return if prev_value == value
      set(name, value)
      # Logging via the rails console is already handled in add_override!
      log(name, value, prev_value, user, detailed_message) unless defined?(Rails::Console)
      SiteSettingChangeResult.new(prev_value, public_send(name))
    else
      raise Discourse::InvalidParameters.new(
              I18n.t("errors.site_settings.invalid_site_setting", name: name),
            )
    end
  end

  def get(name, scoped_to = nil)
    if has_setting?(name)
      if themeable[name]
        if scoped_to.nil? || !scoped_to.key?(:theme_id) || scoped_to[:theme_id].nil?
          raise SiteSettingExtension::InvalidSettingAccess.new(
                  "#{name} requires a theme_id because it is themeable",
                )
        else
          self.public_send(name, scoped_to)
        end
      else
        self.public_send(name)
      end
    else
      raise Discourse::InvalidParameters.new(
              I18n.t("errors.site_settings.invalid_site_setting", name: name),
            )
    end
  end

  if defined?(Rails::Console)
    # Convenience method for debugging site setting issues
    # Returns a hash with information about a specific setting
    def info(name)
      {
        resolved_value: get(name),
        default_value: defaults[name],
        global_override: GlobalSetting.respond_to?(name) ? GlobalSetting.public_send(name) : nil,
        database_value: provider.find(name)&.value,
        refresh?: refresh_settings.include?(name),
        client?: client_settings.include?(name),
        secret?: secret_settings.include?(name),
      }
    end
  end

  def valid_areas
    Set.new(SiteSetting::VALID_AREAS | DiscoursePluginRegistry.site_setting_areas.to_a)
  end

  protected

  def clear_cache!(expire_theme_site_setting_cache: false)
    Discourse.cache.delete(SiteSettingExtension.client_settings_cache_key)
    Theme.expire_site_setting_cache! if expire_theme_site_setting_cache
    Site.clear_anon_cache!
  end

  def diff_hash(new_hash, old)
    changes = []
    deletions = []

    new_hash.each do |name, value|
      changes << [name, value] if !old.has_key?(name) || old[name] != value
    end

    old.each { |name, value| deletions << [name, value] unless new_hash.has_key?(name) }

    [changes, deletions]
  end

  def setup_shadowed_methods(name, value)
    clean_name = name.to_s.sub("?", "").to_sym

    define_singleton_method clean_name do
      value
    end

    define_singleton_method "#{clean_name}?" do
      value
    end

    define_singleton_method "#{clean_name}=" do |val|
      if value != val
        Rails.logger.warn(
          "An attempt was to change #{clean_name} SiteSetting to #{val} however it is shadowed so this will be ignored!",
        )
      end
      nil
    end
  end

  def setup_methods(name)
    clean_name = name.to_s.sub("?", "").to_sym

    if type_supervisor.get_type(name) == :uploaded_image_list
      define_singleton_method clean_name do |scoped_to = nil|
        if themeable[clean_name]
          if scoped_to.nil? || !scoped_to.key?(:theme_id) || scoped_to[:theme_id].nil?
            raise SiteSettingExtension::InvalidSettingAccess.new(
                    "#{clean_name} requires a theme_id because it is themeable",
                  )
          end
        end

        uploads_list = uploads[name]
        return uploads_list if uploads_list

        if (value = current[name]).nil?
          refresh!
          value = current[name]
        end

        return [] if value.empty?

        value = value.split("|").map(&:to_i)
        uploads_list = Upload.where(id: value).to_a
        uploads[name] = uploads_list if uploads_list
      end
    elsif type_supervisor.get_type(name) == :upload
      define_singleton_method clean_name do |scoped_to = nil|
        if themeable[clean_name]
          if scoped_to.nil? || !scoped_to.key?(:theme_id) || scoped_to[:theme_id].nil?
            raise SiteSettingExtension::InvalidSettingAccess.new(
                    "#{clean_name} requires a theme_id because it is themeable",
                  )
          end
        end

        upload = uploads[name]
        return upload if upload

        if (value = current[name]).nil?
          refresh!
          value = current[name]
        end

        value = value.to_i

        if value != Upload::SEEDED_ID_THRESHOLD
          upload = Upload.find_by(id: value)
          uploads[name] = upload if upload
        end
      end
    else
      define_singleton_method clean_name do |scoped_to = nil|
        if themeable[clean_name]
          if scoped_to.nil? || !scoped_to.key?(:theme_id) || scoped_to[:theme_id].nil?
            raise SiteSettingExtension::InvalidSettingAccess.new(
                    "#{clean_name} requires a theme_id because it is themeable",
                  )
          end

          # If the theme hasn't overridden any theme site settings (or changed defaults)
          # then we will just fall back further down bellow to the current site setting value.
          settings_overriden_for_theme = theme_site_settings[scoped_to[:theme_id]]
          if settings_overriden_for_theme && settings_overriden_for_theme.key?(clean_name)
            return settings_overriden_for_theme[clean_name]
          end
        end

        if plugins[name]
          plugin = Discourse.plugins_by_name[plugins[name]]
          return false if !plugin.configurable? && plugin.enabled_site_setting == name
        end

        refresh! if current[name].nil?

        value = current[name]

        if mandatory_values[name]
          return (mandatory_values[name].split("|") | value.to_s.split("|")).join("|")
        end
        value
      end
    end

    # Any group_list setting, e.g. personal_message_enabled_groups, will have
    # a getter defined with _map on the end, e.g. personal_message_enabled_groups_map,
    # to avoid having to manually split and convert to integer for these settings.
    if type_supervisor.get_type(name) == :group_list
      define_singleton_method("#{clean_name}_map") do
        self.public_send(clean_name).to_s.split("|").map(&:to_i)
      end
    end

    # Same logic as above for other list type settings, with the caveat that normal
    # list settings are not necessarily integers, so we just want to handle the splitting.
    if %i[list emoji_list tag_list].include?(type_supervisor.get_type(name))
      list_type = type_supervisor.get_list_type(name)

      if %w[simple compact].include?(list_type) || list_type.nil?
        define_singleton_method("#{clean_name}_map") do |scoped_to = nil|
          self.public_send(clean_name, scoped_to).to_s.split("|")
        end
      end
    end

    define_singleton_method "#{clean_name}?" do |scoped_to = nil|
      self.public_send(clean_name, scoped_to)
    end

    define_singleton_method "#{clean_name}=" do |val|
      raise_invalid_setting_access(clean_name) if themeable[clean_name]

      add_override!(name, val)
    end
  end

  def get_hostname(url)
    host =
      begin
        URI.parse(url)&.host
      rescue URI::Error
        nil
      end

    host ||=
      begin
        URI.parse("http://#{url}")&.host
      rescue URI::Error
        nil
      end

    host.presence || url
  end

  private

  def setting(name_arg, default = nil, opts = {})
    name = name_arg.to_sym

    if name == :default_locale
      raise Discourse::InvalidParameters.new(
              "Other settings depend on default locale, you can not configure it like this",
            )
    end

    shadowed_val = nil

    mutex.synchronize do
      defaults.load_setting(name, default, opts.delete(:locale_default))

      mandatory_values[name] = opts[:mandatory_values] if opts[:mandatory_values]

      requires_confirmation_settings[name] = (
        if SiteSettings::TypeSupervisor::REQUIRES_CONFIRMATION_TYPES.values.include?(
             opts[:requires_confirmation],
           )
          opts[:requires_confirmation]
        end
      )

      categories[name] = opts[:category] || :uncategorized

      themeable[name] = opts[:themeable] ? true : false

      if opts[:area]
        split_areas = opts[:area].split("|")
        if split_areas.any? { |area| !SiteSetting.valid_areas.include?(area) }
          raise Discourse::InvalidParameters.new(
                  "Area is invalid, valid areas are: #{SiteSetting.valid_areas.join(", ")}",
                )
        end
        areas[name] = split_areas
      end
      hidden_settings_provider.add_hidden(name) if opts[:hidden]

      if GlobalSetting.respond_to?(name)
        val = GlobalSetting.public_send(name)

        unless val.nil? || (val == "")
          shadowed_val = val
          hidden_settings_provider.add_hidden(name)
          shadowed_settings << name
        end
      end

      refresh_settings << name if opts[:refresh]

      client_settings << name.to_sym if opts[:client]

      previews[name] = opts[:preview] if opts[:preview]

      secret_settings << name if opts[:secret]

      plugins[name] = opts[:plugin] if opts[:plugin]

      type_supervisor.load_setting(
        name,
        opts.extract!(*SiteSettings::TypeSupervisor::CONSUMED_OPTS),
      )

      if !shadowed_val.nil?
        setup_shadowed_methods(name, shadowed_val)
      else
        setup_methods(name)
      end
    end
  end

  def log(name, value, prev_value, user = Discourse.system_user, detailed_message = nil)
    value = prev_value = "[FILTERED]" if secret_settings.include?(name.to_sym)
    return if hidden_settings.include?(name.to_sym)
    StaffActionLogger.new(user).log_site_setting_change(
      name,
      prev_value,
      value,
      { details: detailed_message }.compact_blank,
    )
  end

  def default_uploads
    @default_uploads ||= {}

    @default_uploads[provider.current_site] ||= begin
      Upload.where("id < ?", Upload::SEEDED_ID_THRESHOLD).pluck(:id, :url).to_h
    end
  end

  def uploads
    @uploads ||= {}
    @uploads[provider.current_site] ||= {}
  end

  def clear_uploads_cache(name)
    if (
         type_supervisor.get_type(name) == :upload ||
           type_supervisor.get_type(name) == :uploaded_image_list
       ) && uploads.has_key?(name)
      uploads.delete(name)
    end
  end

  def logger
    Rails.logger
  end
end
