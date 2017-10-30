require_dependency 'site_settings/deprecated_settings'
require_dependency 'site_settings/type_supervisor'
require_dependency 'site_settings/defaults_provider'
require_dependency 'site_settings/db_provider'

module SiteSettingExtension
  include SiteSettings::DeprecatedSettings
  extend Forwardable

  def_delegator :defaults, :site_locale, :default_locale
  def_delegator :defaults, :site_locale=, :default_locale=
  def_delegator :defaults, :has_setting?
  def_delegators 'SiteSettings::TypeSupervisor', :types, :supported_types

  # part 1 of refactor, centralizing the dependency here
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
    @refresh_settings ||= []
  end

  def client_settings
    @client_settings ||= []
  end

  def previews
    @previews ||= {}
  end

  def setting(name_arg, default = nil, opts = {})
    name = name_arg.to_sym

    shadowed_val = nil

    mutex.synchronize do
      defaults.load_setting(
        name,
        default,
        opts.extract!(*SiteSettings::DefaultsProvider::CONSUMED_OPTS)
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
    defaults.each_key do |s|
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
    defaults
      .reject { |s, _| !include_hidden && hidden_settings.include?(s) }
      .map do |s, v|
      value = send(s)
      opts = {
        setting: s,
        description: description(s),
        default: defaults[s].to_s,
        value: value.to_s,
        category: categories[s],
        preview: previews[s]
      }.merge(type_supervisor.type_hash(s))

      opts
    end.unshift(defaults.locale_setting_hash)
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

      defaults_view = defaults.all

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
    current[name] = defaults[name]
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

  def filter_value(name, value)
    if %w[disabled_image_download_domains onebox_domains_blacklist exclude_rel_nofollow_domains email_domains_blacklist email_domains_whitelist white_listed_spam_host_domains].include? name
      domain_array = []
      value.split('|').each { |url| domain_array << get_hostname(url) }
      value = domain_array.join("|")
    end
    value
  end

  def set(name, value)
    if has_setting?(name)
      value = filter_value(name, value)
      self.send("#{name}=", value)
      Discourse.request_refresh! if requires_refresh?(name)
    else
      raise ArgumentError.new("Either no setting named '#{name}' exists or value provided is invalid")
    end
  end

  def set_and_log(name, value, user = Discourse.system_user)
    prev_value = send(name)
    set(name, value)
    StaffActionLogger.new(user).log_site_setting_change(name, prev_value, value) if has_setting?(name)
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
    unless (URI.parse(url).scheme rescue nil).nil?
      url = "http://#{url}" if URI.parse(url).scheme.nil?
      url = URI.parse(url).host
    end
    url
  end

  private

  def logger
    Rails.logger
  end

end
