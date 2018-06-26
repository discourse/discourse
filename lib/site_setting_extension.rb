# frozen_string_literal: true

require_dependency 'site_settings/deprecated_settings'
require_dependency 'site_settings/type_supervisor'
require_dependency 'site_settings/defaults_provider'
require_dependency 'site_settings/db_provider'

module SiteSettingExtension
  include SiteSettings::DeprecatedSettings

  # support default_locale being set via global settings
  # this also adds support for testing the extension and global settings
  # for site locale
  def self.extended(klass)
    if GlobalSetting.respond_to?(:default_locale) && GlobalSetting.default_locale.present?
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

      if opts[:shadowed_by_global] && GlobalSetting.respond_to?(name)
        val = GlobalSetting.send(name)

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
    defaults.all.keys.each do |s|
      result[s] = send(s).to_s
    end
    result
  end

  def client_settings_json
    Rails.cache.fetch(SiteSettingExtension.client_settings_cache_key, expires_in: 30.minutes) do
      client_settings_json_uncached
    end
  end

  def client_settings_json_uncached
    MultiJson.dump(Hash[*@client_settings.map { |n| [n, self.send(n)] }.flatten])
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
      value = send(s)
      opts = {
        setting: s,
        description: description(s),
        default: defaults.get(s, default_locale).to_s,
        value: value.to_s,
        category: categories[s],
        preview: previews[s],
        secret: secret_settings.include?(s)
      }.merge(type_supervisor.type_hash(s))

      opts
    end.unshift(locale_setting_hash)
  end

  def description(setting)
    I18n.t("site_settings.#{setting}")
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
      shadowed_settings.each { |ss| new_hash[ss] = GlobalSetting.send(ss) }

      changes, deletions = diff_hash(new_hash, current)
      changes.each   { |name, val| current[name] = val }
      deletions.each { |name, _|   current[name] = defaults_view[name] }

      clear_cache!
    end
  end

  def ensure_listen_for_changes
    return if @listen_for_changes == false

    unless @subscribed
      MessageBus.subscribe("/site_settings") do |message|
        process_message(message)
      end
      @subscribed = true
    end
  end

  def process_message(message)
    data = message.data
    if data["process"] != process_id
      begin
        @last_message_processed = message.global_id
        MessageBus.on_connect.call(message.site_id)
        refresh!
      ensure
        MessageBus.on_disconnect.call(message.site_id)
      end
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
    provider.destroy(name)
    current[name] = defaults.get(name, default_locale)
    clear_cache!
  end

  def add_override!(name, val)
    val, type = type_supervisor.to_db_value(name, val)
    provider.save(name, val, type)
    current[name] = type_supervisor.to_rb_value(name, val)
    notify_clients!(name) if client_settings.include? name
    clear_cache!
  end

  def notify_changed!
    MessageBus.publish('/site_settings', process: process_id)
  end

  def notify_clients!(name)
    MessageBus.publish('/client_settings', name: name, value: self.send(name))
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
      value.split("|").map { |url| get_hostname(url) }.compact.uniq.join("|")
    else
      value
    end
  end

  def set(name, value)
    if has_setting?(name)
      value = filter_value(name, value)
      self.send("#{name}=", value)
      Discourse.request_refresh! if requires_refresh?(name)
    else
      raise Discourse::InvalidParameters.new("Either no setting named '#{name}' exists or value provided is invalid")
    end
  end

  def set_and_log(name, value, user = Discourse.system_user)
    prev_value = send(name)
    set(name, value)
    if has_setting?(name)
      value = prev_value = "[FILTERED]" if secret_settings.include?(name.to_sym)
      StaffActionLogger.new(user).log_site_setting_change(name, prev_value, value)
    end
  end

  protected

  def clear_cache!
    Rails.cache.delete(SiteSettingExtension.client_settings_cache_key)
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

    define_singleton_method clean_name do
      if (c = current[name]).nil?
        refresh!
        current[name]
      else
        c
      end
    end

    define_singleton_method "#{clean_name}?" do
      self.send clean_name
    end

    define_singleton_method "#{clean_name}=" do |val|
      add_override!(name, val)
    end
  end

  def get_hostname(url)
    url.strip!

    host = begin
      URI.parse(url)&.host
    rescue URI::InvalidURIError
      nil
    end

    host ||= begin
      URI.parse("http://#{url}")&.host
    rescue URI::InvalidURIError
      nil
    end

    host.presence || url
  end

  private

  def logger
    Rails.logger
  end

end
