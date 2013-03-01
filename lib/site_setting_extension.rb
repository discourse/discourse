require_dependency 'enum'

module SiteSettingExtension

  def types
    @types ||= Enum.new(:string, :time, :fixnum, :float, :bool, :null)
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

  def setting(name, default = nil)
    mutex.synchronize do
      self.defaults[name] = default
      current_value = current.has_key?(name) ? current[name] : default
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


  def client_settings_json
    Rails.cache.fetch(SiteSettingExtension.client_settings_cache_key, expires_in: 30.minutes) do
      MultiJson.dump(Hash[*@@client_settings.map{|n| [n, self.send(n)]}.flatten])
    end
  end

  # Retrieve all settings
  def all_settings
    @defaults.map do |s, v|
      value = send(s)
      {setting: s,
       description: description(s),
       default: v,
       type: types[get_data_type(value)].to_s,
       value: value.to_s}
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
      changes = []
      deletions = []

      all_settings = SiteSetting.select([:name,:value,:data_type])
      new_hash =  Hash[*(all_settings.map{|s| [s.name.intern, convert(s.value,s.data_type)]}.to_a.flatten)]

      # add defaults
      new_hash = defaults.merge(new_hash)

      new_hash.each do |name, value|
        changes << [name,value] if !old.has_key?(name) || old[name] != value
      end

      old.each do |name,value|
        deletions << [name,value] unless new_hash.has_key?(name)
      end

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
      pid = process_id
      MessageBus.subscribe("/site_settings") do |msg|
        message = msg.data
        if message["process"] != pid
          begin
            # picks a db
            MessageBus.on_connect.call(msg.site_id)
            SiteSetting.refresh!
          ensure
            MessageBus.on_disconnect.call(msg.site_id)
          end
        end
      end
      @subscribed = true
    end
  end

  def process_id
    @@process_id ||= SecureRandom.uuid
  end

  def remove_override!(name)
    return unless table_exists?
    SiteSetting.where(:name => name).destroy_all
  end

  def add_override!(name,val)
    return unless table_exists?

    setting = SiteSetting.where(:name => name).first
    type = get_data_type(defaults[name])

    if type == types[:bool] && val != true && val != false
      val = (val == "t" || val == "true") ? 't' : 'f'
    end

    if type == types[:fixnum] && !(Fixnum === val)
      val = val.to_i
    end

    if type == types[:null] && val != ''
      type = get_data_type(val)
    end

    if setting
      setting.value = val
      setting.data_type = type
      setting.save
    else
      SiteSetting.create!(:name => name, :value => val, :data_type => type)
    end

    MessageBus.publish('/site_settings', {process: process_id})
  end


  protected

  def get_data_type(val)
    return types[:null] if val.nil?

    if String === val
      types[:string]
    elsif Fixnum === val
      types[:fixnum]
    elsif TrueClass === val || FalseClass === val
      types[:bool]
    else
      raise ArgumentError.new :val
    end
  end

  def convert(value, type)
    case type
    when types[:fixnum]
      value.to_i
    when types[:string]
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


end

