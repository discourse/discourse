require_dependency 'enum'

module SiteSettingExtension

  def types
    @types ||= Enum.new(:string, :time, :fixnum, :float, :bool, :null, :enum)
  end

  def mutex
    @mutex ||= Mutex.new
  end

  def current
    @@containers ||= {}
    @@containers[RailsMultisite::ConnectionManagement.current_db] ||= {}
  end

  def defaults
    @defaults ||= {}
  end

  def enums
    @enums ||= {}
  end

  def setting(name, default = nil, opts = {})
    mutex.synchronize do
      self.defaults[name] = default
      current_value = current.has_key?(name) ? current[name] : default
      enums[name] = opts[:enum] if opts[:enum]
      setup_methods(name, current_value)
    end
  end

  # just like a setting, except that it is available in javascript via DiscourseSession
  def client_setting(name, default = nil)
    setting(name,default)
    @@client_settings ||= []
    @@client_settings << name
  end

  def client_settings
    @@client_settings
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
      MultiJson.dump(Hash[*@@client_settings.map{|n| [n, self.send(n)]}.flatten])
    end
  end

  # Retrieve all settings
  def all_settings
    @defaults.map do |s, v|
      value = send(s)
      type = types[get_data_type(s, value)]
      {setting: s,
       description: description(s),
       default: v,
       type: type.to_s,
       value: value.to_s}.merge( type == :enum ? {valid_values: enum_class(s).all_values} : {})
    end
  end

  def description(setting)
    I18n.t("site_settings.#{setting}")
  end

  # table is not in the db yet, initial migration, etc
  def table_exists?
    @table_exists = ActiveRecord::Base.connection.table_exists? 'site_settings' if @table_exists == nil
    @table_exists
  end

  def self.client_settings_cache_key
    "client_settings_json"
  end

  # refresh all the site settings
  def refresh!
    return unless table_exists?
    mutex.synchronize do
      ensure_listen_for_changes
      old = current

      all_settings = SiteSetting.select([:name,:value,:data_type])
      new_hash =  Hash[*(all_settings.map{|s| [s.name.intern, convert(s.value,s.data_type)]}.to_a.flatten)]

      # add defaults
      new_hash = defaults.merge(new_hash)

      changes,deletions = diff_hash(new_hash, old)

      if deletions.length > 0 || changes.length > 0
        @current = new_hash
        changes.each do |name, val|
          setup_methods name, val
        end
        deletions.each do |name,val|
          setup_methods name, defaults[name]
        end
      end

      Rails.cache.delete(SiteSettingExtension.client_settings_cache_key)
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
        SiteSetting.refresh!
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
    @@process_id ||= SecureRandom.uuid
  end

  def remove_override!(name)
    return unless table_exists?
    SiteSetting.where(name: name).destroy_all
  end

  def add_override!(name,val)
    return unless table_exists?

    setting = SiteSetting.where(name: name).first
    type = get_data_type(name, defaults[name])

    if type == types[:bool] && val != true && val != false
      val = (val == "t" || val == "true") ? 't' : 'f'
    end

    if type == types[:fixnum] && !(Fixnum === val)
      val = val.to_i
    end

    if type == types[:null] && val != ''
      type = get_data_type(name, val)
    end

    if type == types[:enum]
      raise Discourse::InvalidParameters.new(:value) unless enum_class(name).valid_value?(val)
    end

    if setting
      setting.value = val
      setting.data_type = type
      setting.save
    else
      SiteSetting.create!(name: name, value: val, data_type: type)
    end

    @last_message_sent = MessageBus.publish('/site_settings', {process: process_id})
  end


  protected

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
    when types[:string], types[:enum]
      value
    when types[:bool]
      value == "t"
    when types[:null]
      nil
    end
  end


  def setup_methods(name, current_value)

    # trivial multi db support, we can optimize this later
    db = RailsMultisite::ConnectionManagement.current_db

    @@containers ||= {}
    @@containers[db] ||= {}
    @@containers[db][name] = current_value

    setter = ("#{name}=").sub("?","")

    eval "define_singleton_method :#{name} do
      c = @@containers[RailsMultisite::ConnectionManagement.current_db]
      c = c[name] if c
      c
    end

    define_singleton_method :#{setter} do |val|
      add_override!(:#{name}, val)
      refresh!
    end
    "
  end

  def method_missing(method, *args, &block)
    as_question = method.to_s.gsub(/\?$/, '')
    if respond_to?(as_question)
      return send(as_question, *args, &block)
    end
    super(method, *args, &block)
  end

  def enum_class(name)
    enums[name] = enums[name].constantize unless enums[name].is_a?(Class)
    enums[name]
  end

end

