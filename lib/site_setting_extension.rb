require_dependency 'enum'
require_dependency 'site_settings/db_provider'
require 'site_setting_validations'

module SiteSettingExtension
  include SiteSettingValidations

  # For plugins, so they can tell if a feature is supported
  def supported_types
    [:email, :username, :list, :enum]
  end

  # part 1 of refactor, centralizing the dependency here
  def provider=(val)
    @provider = val
    refresh!
  end

  def provider
    @provider ||= SiteSettings::DbProvider.new(SiteSetting)
  end

  def types
    @types ||= Enum.new(string: 1,
                        time: 2,
                        fixnum: 3,
                        float: 4,
                        bool: 5,
                        null: 6,
                        enum: 7,
                        list: 8,
                        url_list: 9,
                        host_list: 10,
                        category_list: 11,
                        value_list: 12)
  end

  def mutex
    @mutex ||= Mutex.new
  end

  def current
    @containers ||= {}
    @containers[provider.current_site] ||= {}
  end

  def defaults
    @defaults ||= {}
  end

  def categories
    @categories ||= {}
  end

  def enums
    @enums ||= {}
  end

  def static_types
    @static_types ||= {}
  end

  def choices
    @choices ||= {}
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

  def validators
    @validators ||= {}
  end

  def setting(name_arg, default = nil, opts = {})
    name = name_arg.to_sym
    mutex.synchronize do
      self.defaults[name] = default
      categories[name] = opts[:category] || :uncategorized
      current_value = current.has_key?(name) ? current[name] : default

      if enum = opts[:enum]
        enums[name] = enum.is_a?(String) ? enum.constantize : enum
        opts[:type] ||= :enum
      end

      if new_choices = opts[:choices]

        new_choices = eval(new_choices) if new_choices.is_a?(String)

        choices.has_key?(name) ?
          choices[name].concat(new_choices) :
          choices[name] = new_choices
      end

      if type = opts[:type]
        static_types[name.to_sym] = type.to_sym
      end

      if opts[:hidden]
        hidden_settings << name
      end

      # You can "shadow" a site setting with a GlobalSetting. If the GlobalSetting
      # exists it will be used instead of the setting and the setting will be hidden.
      # Useful for things like API keys on multisite.
      if opts[:shadowed_by_global] && GlobalSetting.respond_to?(name)
        val = GlobalSetting.send(name)
        unless val.nil? || (val == ''.freeze)
          hidden_settings << name
          shadowed_settings << name
          current_value = val
        end
      end

      if opts[:refresh]
        refresh_settings << name
      end

      if opts[:preview]
        previews[name] = opts[:preview]
      end

      opts[:validator] = opts[:validator].try(:constantize)
      type = opts[:type] || get_data_type(name, defaults[name])

      if validator_type = opts[:validator] || validator_for(type)
        validators[name] = { class: validator_type, opts: opts }
      end

      current[name] = current_value
      setup_methods(name)
    end
  end

  # just like a setting, except that it is available in javascript via DiscourseSession
  def client_setting(name, default = nil, opts = {})
    setting(name, default, opts)
    client_settings << name.to_sym
  end

  def settings_hash
    result = {}
    @defaults.each do |s, _|
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
    MultiJson.dump(Hash[*@client_settings.map{|n| [n, self.send(n)]}.flatten])
  end

  # Retrieve all settings
  def all_settings(include_hidden=false)
    @defaults
      .reject{|s, _| hidden_settings.include?(s) && !include_hidden}
      .map do |s, v|
        value = send(s)
        type = types[get_data_type(s, value)]
        opts = {
          setting: s,
          description: description(s),
          default: v.to_s,
          type: type.to_s,
          value: value.to_s,
          category: categories[s],
          preview: previews[s]
        }

        if type == :enum && enum_class(s)
          opts.merge!({valid_values: enum_class(s).values, translate_names: enum_class(s).translate_names?})
        elsif type == :enum
          opts.merge!({valid_values: choices[s].map{|c| {name: c, value: c}}, translate_names: false})
        end

        opts[:choices] = choices[s] if choices.has_key? s
        opts
      end
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
      old = current

      new_hash =  Hash[*(provider.all.map { |s|
        [s.name.intern, convert(s.value, s.data_type, s.name)]
      }.to_a.flatten)]

      # add defaults, cause they are cached
      new_hash = defaults.merge(new_hash)

      # add shadowed
      shadowed_settings.each { |ss| new_hash[ss] = GlobalSetting.send(ss) }

      changes, deletions = diff_hash(new_hash, old)

      changes.each   { |name, val| current[name] = val }
      deletions.each { |name, val| current[name] = defaults[name] }

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
    type = get_data_type(name, defaults[name.to_sym])

    if type == types[:bool] && val != true && val != false
      val = (val == "t" || val == "true") ? 't' : 'f'
    end

    if type == types[:fixnum] && !val.is_a?(Fixnum)
      val = val.to_i
    end

    if type == types[:null] && val != ''
      type = get_data_type(name, val)
    end

    if type == types[:enum]
      val = val.to_i if defaults[name.to_sym].is_a?(Fixnum)
      if enum_class(name)
        raise Discourse::InvalidParameters.new(:value) unless enum_class(name).valid_value?(val)
      else
        raise Discourse::InvalidParameters.new(:value) unless choices[name].include?(val)
      end
    end

    if v = validators[name]
      validator = v[:class].new(v[:opts])
      unless validator.valid_value?(val)
        raise Discourse::InvalidParameters.new(validator.error_message)
      end
    end

    if self.respond_to? "validate_#{name}"
      send("validate_#{name}", val)
    end

    provider.save(name, val, type)
    current[name] = convert(val, type, name)
    notify_clients!(name) if client_settings.include? name
    clear_cache!
  end

  def notify_changed!
    MessageBus.publish('/site_settings', {process: process_id})
  end

  def notify_clients!(name)
    MessageBus.publish('/client_settings', {name: name, value: self.send(name)})
  end

  def has_setting?(name)
    defaults.has_key?(name.to_sym) || defaults.has_key?("#{name}?".to_sym)
  end

  def requires_refresh?(name)
    refresh_settings.include?(name.to_sym)
  end

  def is_valid_data?(name, value)
    valid = true
    type = get_data_type(name, defaults[name.to_sym])

    if type == types[:fixnum]
      # validate fixnum
      valid = false unless value.to_i.is_a?(Fixnum)
    end

    valid
  end

  def filter_value(name, value)
    # filter domain name
    if %w[disabled_image_download_domains onebox_domains_whitelist exclude_rel_nofollow_domains email_domains_blacklist email_domains_whitelist white_listed_spam_host_domains].include? name
      domain_array = []
      value.split('|').each { |url|
        domain_array.push(get_hostname(url))
      }
      value = domain_array.join("|")
    end
    value
  end

  def set(name, value)
    if has_setting?(name) && is_valid_data?(name, value)
      value = filter_value(name, value)
      self.send("#{name}=", value)
      Discourse.request_refresh! if requires_refresh?(name)
    else
      raise ArgumentError.new("Either no setting named '#{name}' exists or value provided is invalid")
    end
  end

  def set_and_log(name, value, user=Discourse.system_user)
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
      changes << [name,value] if !old.has_key?(name) || old[name] != value
    end

    old.each do |name,value|
      deletions << [name,value] unless new_hash.has_key?(name)
    end

    [changes,deletions]
  end

  def get_data_type(name, val)
    return types[:null] if val.nil?

    # Some types are just for validations like email.
    # Only consider it valid if includes in `types`
    if static_type = static_types[name.to_sym]
      return types[static_type] if types.keys.include?(static_type)
    end

    case val
    when String
      types[:string]
    when Fixnum
      types[:fixnum]
    when Float
      types[:float]
    when TrueClass, FalseClass
      types[:bool]
    else
      raise ArgumentError.new :val
    end
  end

  def convert(value, type, name)
    case type
    when types[:float]
      value.to_f
    when types[:fixnum]
      value.to_i
    when types[:bool]
      value == true || value == "t" || value == "true"
    when types[:null]
      nil
    when types[:enum]
      defaults[name.to_sym].is_a?(Fixnum) ? value.to_i : value
    else
      return value if types[type]
      # Otherwise it's a type error
      raise ArgumentError.new :type
    end
  end

  def validator_for(type_name)
    @validator_mapping ||= {
      'email'        => EmailSettingValidator,
      'username'     => UsernameSettingValidator,
      types[:fixnum] => IntegerSettingValidator,
      types[:string] => StringSettingValidator,
      'list' => StringSettingValidator,
      'enum' => StringSettingValidator
    }
    @validator_mapping[type_name]
  end


  def setup_methods(name)
    clean_name = name.to_s.sub("?", "").to_sym

    define_singleton_method clean_name do
      c = @containers[provider.current_site]
      if c
        c[name]
      else
        refresh!
        current[name]
      end
    end

    define_singleton_method "#{clean_name}?" do
      self.send clean_name
    end

    define_singleton_method "#{clean_name}=" do |val|
      add_override!(name, val)
    end
  end

  def enum_class(name)
    enums[name]
  end

  def get_hostname(url)
    unless (URI.parse(url).scheme rescue nil).nil?
      url = "http://#{url}" if URI.parse(url).scheme.nil?
      url = URI.parse(url).host
    end
    url
  end

end
