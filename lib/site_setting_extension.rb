require_dependency 'enum'
require_dependency 'site_settings/db_provider'

module SiteSettingExtension

  # part 1 of refactor, centralizing the dependency here
  def provider=(val)
    @provider = val
    refresh!
  end

  def provider
    @provider ||= SiteSettings::DbProvider.new(SiteSetting)
  end

  def types
    @types ||= Enum.new(:string, :time, :fixnum, :float, :bool, :null, :enum, :list)
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

  def lists
    @lists ||= []
  end

  def choices
    @choices ||= {}
  end

  def hidden_settings
    @hidden_settings ||= []
  end

  def refresh_settings
    @refresh_settings ||= []
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
      if opts[:enum]
        enum = opts[:enum]
        enums[name] = enum.is_a?(String) ? enum.constantize : enum
      end
      if opts[:choices]
        choices.has_key?(name) ?
          choices[name].concat(opts[:choices]) :
          choices[name] = opts[:choices]
      end
      if opts[:type] == 'list'
        lists << name
      end
      if opts[:hidden]
        hidden_settings << name
      end
      if opts[:refresh]
        refresh_settings << name
      end

      if validator_type = validator_for(opts[:type] || get_data_type(name, defaults[name]))
        validators[name] = {class: validator_type, opts: opts}
      end

      current[name] = current_value
      setup_methods(name, current_value)
    end
  end

  # just like a setting, except that it is available in javascript via DiscourseSession
  def client_setting(name, default = nil, opts = {})
    setting(name, default, opts)
    @client_settings ||= []
    @client_settings << name
  end

  def client_settings
    @client_settings ||= []
  end

  def settings_hash
    result = {}
    @defaults.each do |s, v|
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
      .reject{|s, v| hidden_settings.include?(s) || include_hidden}
      .map do |s, v|
        value = send(s)
        type = types[get_data_type(s, value)]
        opts = {
          setting: s,
          description: description(s),
          default: v,
          type: type.to_s,
          value: value.to_s,
          category: categories[s]
        }
        opts.merge!({valid_values: enum_class(s).values, translate_names: enum_class(s).translate_names?}) if type == :enum
        opts[:choices] = choices[s] if choices.has_key? s
        opts
      end
  end

  def description(setting)
    I18n.t("site_settings.#{setting}")
  end

  def self.client_settings_cache_key
    "client_settings_json"
  end

  # refresh all the site settings
  def refresh!
    mutex.synchronize do
      ensure_listen_for_changes
      old = current

      new_hash =  Hash[*(provider.all.map{ |s|
        [s.name.intern, convert(s.value,s.data_type)]
      }.to_a.flatten)]

      # add defaults, cause they are cached
      new_hash = defaults.merge(new_hash)

      changes,deletions = diff_hash(new_hash, old)

      if deletions.length > 0 || changes.length > 0
        changes.each do |name, val|
          current[name] = val
        end
        deletions.each do |name,val|
          current[name] = defaults[name]
        end
      end
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

  def add_override!(name,val)
    type = get_data_type(name, defaults[name])

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
      raise Discourse::InvalidParameters.new(:value) unless enum_class(name).valid_value?(val)
    end

    if v = validators[name]
      validator = v[:class].new(v[:opts])
      unless validator.valid_value?(val)
        raise Discourse::InvalidParameters.new(validator.error_message)
      end
    end

    provider.save(name, val, type)
    current[name] = convert(val, type)
    clear_cache!
  end

  def notify_changed!
    MessageBus.publish('/site_settings', {process: process_id})
  end

  def has_setting?(name)
    defaults.has_key?(name.to_sym) || defaults.has_key?("#{name}?".to_sym)
  end

  def requires_refresh?(name)
    refresh_settings.include?(name.to_sym)
  end

  def set(name, value)
    if has_setting?(name)
      self.send("#{name}=", value)
      Discourse.request_refresh! if requires_refresh?(name)
    else
      raise ArgumentError.new("No setting named #{name} exists")
    end
  end

  protected

  def clear_cache!
    Rails.cache.delete(SiteSettingExtension.client_settings_cache_key)
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

  def get_data_type(name,val)
    return types[:null] if val.nil?
    return types[:enum] if enums[name]
    return types[:list] if lists.include? name

    case val
    when String
      types[:string]
    when Fixnum
      types[:fixnum]
    when TrueClass, FalseClass
      types[:bool]
    else
      raise ArgumentError.new :val
    end
  end

  def convert(value, type)
    case type
    when types[:fixnum]
      value.to_i
    when types[:string], types[:list], types[:enum]
      value
    when types[:bool]
      value == true || value == "t" || value == "true"
    when types[:null]
      nil
    else
      raise ArgumentError.new :type
    end
  end

  def validator_for(type_name)
    @validator_mapping ||= {
      'email'        => EmailSettingValidator,
      'username'     => UsernameSettingValidator,
      types[:fixnum] => IntegerSettingValidator,
      types[:string] => StringSettingValidator
    }
    @validator_mapping[type_name]
  end


  def setup_methods(name, current_value)

    clean_name = name.to_s.sub("?", "")

    eval "define_singleton_method :#{clean_name} do
      c = @containers[provider.current_site]
      if c
        c[name]
      else
        refresh!
        current[name]
      end
    end

    define_singleton_method :#{clean_name}? do
      #{clean_name}
    end

    define_singleton_method :#{clean_name}= do |val|
      add_override!(:#{name}, val)
    end
    "
  end

  def enum_class(name)
    enums[name]
  end

end

