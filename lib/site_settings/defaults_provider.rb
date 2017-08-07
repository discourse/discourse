module SiteSettings; end

# A cache for providing default value based on site locale
class SiteSettings::DefaultsProvider
  include Enumerable

  CONSUMED_OPTS = %i[default locale_default].freeze
  DEFAULT_LOCALE_KEY = :default_locale
  DEFAULT_LOCALE = 'en'.freeze
  DEFAULT_CATEGORY = 'required'.freeze

  def initialize(site_setting)
    @site_setting = site_setting
    @site_setting.refresh_settings << DEFAULT_LOCALE_KEY

    @cached = {}
    @defaults = {}
    @defaults[DEFAULT_LOCALE.to_sym] = {}
    @site_locale = nil
    refresh_site_locale!
  end

  def load_setting(name_arg, value, opts = {})
    name = name_arg.to_sym
    @defaults[DEFAULT_LOCALE.to_sym][name] = value

    if (locale_default = opts[:locale_default])
      locale_default.each do |locale, v|
        locale = locale.to_sym
        @defaults[locale] ||= {}
        @defaults[locale][name] = v
      end
    end
    refresh_cache!
  end

  def db_all
    @site_setting.provider.all.delete_if { |s| s.name.to_sym == DEFAULT_LOCALE_KEY }
  end

  def all
    @cached
  end

  def get(name)
    @cached[name.to_sym]
  end

  # Used to override site settings in dev/test env
  def set_regardless_of_locale(name, value)
    name = name.to_sym
    if @site_setting.has_setting?(name)
      @defaults.each { |_, hash| hash.delete(name) }
      @defaults[DEFAULT_LOCALE.to_sym][name] = value
      value, type = @site_setting.type_supervisor.to_db_value(name, value)
      @cached[name] = @site_setting.type_supervisor.to_rb_value(name, value, type)
    else
      raise ArgumentError.new("No setting named '#{name}' exists")
    end
  end

  alias [] get

  attr_reader :site_locale

  def site_locale=(val)
    val = val.to_s
    raise Discourse::InvalidParameters.new(:value) unless LocaleSiteSetting.valid_value?(val)

    if val != @site_locale
      @site_setting.provider.save(DEFAULT_LOCALE_KEY, val, SiteSetting.types[:string])
      refresh_site_locale!
      @site_setting.refresh!
      Discourse.request_refresh!
    end

    @site_locale
  end

  def each
    @cached.each { |k, v| yield k.to_sym, v }
  end

  def locale_setting_hash
    {
      setting: DEFAULT_LOCALE_KEY,
      default: DEFAULT_LOCALE,
      category: DEFAULT_CATEGORY,
      description: @site_setting.description(DEFAULT_LOCALE_KEY),
      type: SiteSetting.types[SiteSetting.types[:enum]],
      preview: nil,
      value: @site_locale,
      valid_values: LocaleSiteSetting.values,
      translate_names: LocaleSiteSetting.translate_names?
    }
  end

  def refresh_site_locale!
    if GlobalSetting.respond_to?(DEFAULT_LOCALE_KEY) &&
        (global_val = GlobalSetting.send(DEFAULT_LOCALE_KEY)) &&
        !global_val.blank?
      @site_locale = global_val
    elsif (db_val = @site_setting.provider.find(DEFAULT_LOCALE_KEY))
      @site_locale = db_val.value.to_s
    else
      @site_locale = DEFAULT_LOCALE
    end
    refresh_cache!
    @site_locale
  end

  def has_setting?(name)
    has_key?(name.to_sym) || has_key?("#{name.to_s}?".to_sym)
  end

  private

  def has_key?(key)
    @cached.key?(key) || key == DEFAULT_LOCALE_KEY
  end

  def refresh_cache!
    @cached = @defaults[DEFAULT_LOCALE.to_sym].merge(@defaults.fetch(@site_locale.to_sym, {}))
  end

end
