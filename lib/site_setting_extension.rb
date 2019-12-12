# frozen_string_literal: true

module SiteSettingExtension
  include SiteSettings::DeprecatedSettings

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

  def defaults
    @defaults ||= SiteSettings::DefaultsProvider.new(self)
  end

  def type_supervisor
    @type_supervisor ||= SiteSettings::TypeSupervisor.new(defaults)
  end

  def categories
    @categories ||= {}
  end

  def shadowed_settings
    @shadowed_settings ||= []
  end

  def hidden_settings
    @hidden_settings ||= []
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
    @secret_settings ||= []
  end

  def setting(name_arg, default = nil, opts = {})
    name = name_arg.to_sym

    if name == :default_locale
      raise Discourse::InvalidParameters.new("Other settings depend on default locale, you can not configure it like this")
    end

    shadowed_val = nil

    mutex.synchronize do
      defaults.load_setting(
        name,
        default,
        opts.delete(:locale_default)
      )

      categories[name] = opts[:category] || :uncategorized

      if opts[:hidden]
        hidden_settings << name
      end

      if GlobalSetting.respond_to?(name)
        val = GlobalSetting.public_send(name)

        unless val.nil? || (val == ''.freeze)
          shadowed_val = val
          hidden_settings << name
          shadowed_settings << name
        end
      end

      if opts[:refresh]
        refresh_settings << name
      end

      if opts[:client]
        client_settings << name.to_sym
      end

      if opts[:preview]
        previews[name] = opts[:preview]
      end

      if opts[:secret]
        secret_settings << name
      end

      type_supervisor.load_setting(
        name,
        opts.extract!(*SiteSettings::TypeSupervisor::CONSUMED_OPTS)
      )

      if !shadowed_val.nil?
        setup_shadowed_methods(name, shadowed_val)
      else
        setup_methods(name)
      end
    end
  end

  def settings_hash
    result = {}
    deprecated_settings = Set.new

    SiteSettings::DeprecatedSettings::SETTINGS.each do |s|
      deprecated_settings << s[0]
    end

    defaults.all.keys.each do |s|
      result[s] =
        if deprecated_settings.include?(s.to_s)
          public_send(s, warn: false).to_s
        else
          public_send(s).to_s
        end
    end

    result
  end

  def client_settings_json
    Discourse.cache.fetch(SiteSettingExtension.client_settings_cache_key, expires_in: 30.minutes) do
      client_settings_json_uncached
    end
  end

  def client_settings_json_uncached
    MultiJson.dump(Hash[*@client_settings.map do |name|
      value = self.public_send(name)
      value = value.to_s if type_supervisor.get_type(name) == :upload
      [name, value]
    end.flatten])
  end

  # Retrieve all settings
  def all_settings(include_hidden = false)

    locale_setting_hash =
    {
      setting: 'default_locale',
      default: SiteSettings::DefaultsProvider::DEFAULT_LOCALE,
      category: 'required',
      description: description('default_locale'),
      type: SiteSetting.types[SiteSetting.types[:enum]],
      preview: nil,
      value: self.default_locale,
      valid_values: LocaleSiteSetting.values,
      translate_names: LocaleSiteSetting.translate_names?
    }

    defaults.all(default_locale)
      .reject { |s, _| !include_hidden && hidden_settings.include?(s) }
      .map do |s, v|

      value = public_send(s)
      type_hash = type_supervisor.type_hash(s)
      default = defaults.get(s, default_locale).to_s

      if type_hash[:type].to_s == "upload" &&
         default.to_i < Upload::SEEDED_ID_THRESHOLD

        default = default_uploads[default.to_i]
      end

      opts = {
        setting: s,
        description: description(s),
        default: default,
        value: value.to_s,
        category: categories[s],
        preview: previews[s],
        secret: secret_settings.include?(s),
        placeholder: placeholder(s)
      }.merge!(type_hash)

      opts
    end.unshift(locale_setting_hash)
  end

  def description(setting)
    I18n.t("site_settings.#{setting}", base_path: Discourse.base_path)
  end

  def placeholder(setting)
    if !I18n.t("site_settings.placeholder.#{setting}", default: "").empty?
      I18n.t("site_settings.placeholder.#{setting}")
    elsif SiteIconManager.respond_to?("#{setting}_url")
      SiteIconManager.public_send("#{setting}_url")
    end
  end

  def self.client_settings_cache_key
    # NOTE: we use the git version in the key to ensure
    # that we don't end up caching the incorrect version
    # in cases where we are cycling unicorns
    "client_settings_json_#{Discourse.git_version}"
  end

  # refresh all the site settings
  def refresh!
    mutex.synchronize do
      ensure_listen_for_changes

      new_hash = Hash[*(defaults.db_all.map { |s|
        [s.name.to_sym, type_supervisor.to_rb_value(s.name, s.value, s.data_type)]
      }.to_a.flatten)]

      defaults_view = defaults.all(new_hash[:default_locale])

      # add locale default and defaults based on default_locale, cause they are cached
      new_hash = defaults_view.merge!(new_hash)

      # add shadowed
      shadowed_settings.each { |ss| new_hash[ss] = GlobalSetting.public_send(ss) }

      changes, deletions = diff_hash(new_hash, current)

      changes.each { |name, val| current[name] = val }
      deletions.each { |name, _| current[name] = defaults_view[name] }
      uploads.clear

      clear_cache!
    end
  end

  def ensure_listen_for_changes
    return if @listen_for_changes == false

    unless @subscribed
      MessageBus.subscribe("/site_settings") do |message|
        if message.data["process"] != process_id
          process_message(message)
        end
      end

      @subscribed = true
    end
  end

  def process_message(message)
    begin
      @last_message_processed = message.global_id
      MessageBus.on_connect.call(message.site_id)
      refresh!
    ensure
      MessageBus.on_disconnect.call(message.site_id)
    end
  end

  def diags
    {
      last_message_processed: @last_message_processed
    }
  end

  def process_id
    @process_id ||= SecureRandom.uuid
  end

  def after_fork
    @process_id = nil
    ensure_listen_for_changes
  end

  def remove_override!(name)
    old_val = current[name]
    provider.destroy(name)
    current[name] = defaults.get(name, default_locale)
    clear_uploads_cache(name)
    clear_cache!
    DiscourseEvent.trigger(:site_setting_changed, name, old_val, current[name]) if old_val != current[name]
  end

  def add_override!(name, val)
    old_val = current[name]
    val, type = type_supervisor.to_db_value(name, val)
    provider.save(name, val, type)
    current[name] = type_supervisor.to_rb_value(name, val)
    clear_uploads_cache(name)
    notify_clients!(name) if client_settings.include? name
    clear_cache!
    DiscourseEvent.trigger(:site_setting_changed, name, old_val, current[name]) if old_val != current[name]
  end

  def notify_changed!
    MessageBus.publish('/site_settings', process: process_id)
  end

  def notify_clients!(name)
    MessageBus.publish('/client_settings', name: name, value: self.public_send(name))
  end

  def requires_refresh?(name)
    refresh_settings.include?(name.to_sym)
  end

  HOSTNAME_SETTINGS ||= %w{
    disabled_image_download_domains onebox_domains_blacklist exclude_rel_nofollow_domains
    email_domains_blacklist email_domains_whitelist white_listed_spam_host_domains
  }

  def filter_value(name, value)
    if HOSTNAME_SETTINGS.include?(name)
      value.split("|").map { |url| url.strip!; get_hostname(url) }.compact.uniq.join("|")
    else
      value
    end
  end

  def set(name, value, options = nil)
    if has_setting?(name)
      value = filter_value(name, value)
      if options
        self.public_send("#{name}=", value, options)
      else
        self.public_send("#{name}=", value)
      end
      Discourse.request_refresh! if requires_refresh?(name)
    else
      raise Discourse::InvalidParameters.new("Either no setting named '#{name}' exists or value provided is invalid")
    end
  end

  def set_and_log(name, value, user = Discourse.system_user)
    if has_setting?(name)
      prev_value = public_send(name)
      set(name, value)
      value = prev_value = "[FILTERED]" if secret_settings.include?(name.to_sym)
      StaffActionLogger.new(user).log_site_setting_change(name, prev_value, value)
    else
      raise Discourse::InvalidParameters.new("No setting named '#{name}' exists")
    end
  end

  def get(name)
    if has_setting?(name)
      self.public_send(name)
    else
      raise Discourse::InvalidParameters.new("No setting named '#{name}' exists")
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

  protected

  def clear_cache!
    Discourse.cache.delete(SiteSettingExtension.client_settings_cache_key)
    Site.clear_anon_cache!
  end

  def diff_hash(new_hash, old)
    changes = []
    deletions = []

    new_hash.each do |name, value|
      changes << [name, value] if !old.has_key?(name) || old[name] != value
    end

    old.each do |name, value|
      deletions << [name, value] unless new_hash.has_key?(name)
    end

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
      Rails.logger.warn("An attempt was to change #{clean_name} SiteSetting to #{val} however it is shadowed so this will be ignored!")
      nil
    end

  end

  def setup_methods(name)
    clean_name = name.to_s.sub("?", "").to_sym

    if type_supervisor.get_type(name) == :upload
      define_singleton_method clean_name do
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
      define_singleton_method clean_name do
        if (c = current[name]).nil?
          refresh!
          current[name]
        else
          c
        end
      end
    end

    define_singleton_method "#{clean_name}?" do
      self.public_send clean_name
    end

    define_singleton_method "#{clean_name}=" do |val|
      add_override!(name, val)
    end
  end

  def get_hostname(url)

    host = begin
      URI.parse(url)&.host
    rescue URI::Error
      nil
    end

    host ||= begin
      URI.parse("http://#{url}")&.host
    rescue URI::Error
      nil
    end

    host.presence || url
  end

  private

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
    if type_supervisor.get_type(name) == :upload && uploads.has_key?(name)
      uploads.delete(name)
    end
  end

  def logger
    Rails.logger
  end

end
