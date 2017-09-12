module SiteSettings; end

# A cache for providing default value based on site locale
class SiteSettings::DefaultsProvider
  include Enumerable

  CONSUMED_OPTS = %i[default locale_default].freeze
  DEFAULT_LOCALE_KEY = :default_locale
  DEFAULT_LOCALE = 'en'.freeze
  DEFAULT_CATEGORY = 'required'.freeze

  @@site_locales ||= DistributedCache.new('site_locales')

  def initialize(site_setting)
    @site_setting = site_setting
    @site_setting.refresh_settings << DEFAULT_LOCALE_KEY
    @defaults = {}
    @defaults[DEFAULT_LOCALE.to_sym] = {}

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
  end

  def db_all
    @site_setting.provider.all.delete_if { |s| s.name.to_sym == DEFAULT_LOCALE_KEY }
  end

  def all
    @defaults[DEFAULT_LOCALE.to_sym].merge(@defaults[self.site_locale.to_sym] || {})
  end

  def get(name)
    @defaults.dig(self.site_locale.to_sym, name.to_sym) ||
      @defaults.dig(DEFAULT_LOCALE.to_sym, name.to_sym)
  end
  alias [] get

  # Used to override site settings in dev/test env
  def set_regardless_of_locale(name, value)
    name = name.to_sym
    if @site_setting.has_setting?(name)
      @defaults.each { |_, hash| hash.delete(name) }
      @defaults[DEFAULT_LOCALE.to_sym][name] = value
      value, type = @site_setting.type_supervisor.to_db_value(name, value)
      @defaults[self.site_locale.to_sym] ||= {}
      @defaults[self.site_locale.to_sym][name] = @site_setting.type_supervisor.to_rb_value(name, value, type)
    else
      raise ArgumentError.new("No setting named '#{name}' exists")
    end
  end

  def site_locale
    @@site_locales[current_db]
  end

  def site_locale=(val)
    val = val.to_s
    raise Discourse::InvalidParameters.new(:value) unless LocaleSiteSetting.valid_value?(val)

    if val != @@site_locales[current_db]
      @site_setting.provider.save(DEFAULT_LOCALE_KEY, val, SiteSetting.types[:string])
      refresh_site_locale!
      @site_setting.refresh!
      Discourse.request_refresh!
    end

    @@site_locales[current_db]
  end

  def each(&block)
    self.all.each do |key, value|
      block.call(key.to_sym, value)
    end
  end

  def locale_setting_hash
    {
      setting: DEFAULT_LOCALE_KEY,
      default: DEFAULT_LOCALE,
      category: DEFAULT_CATEGORY,
      description: @site_setting.description(DEFAULT_LOCALE_KEY),
      type: SiteSetting.types[SiteSetting.types[:enum]],
      preview: nil,
      value: @@site_locales[current_db],
      valid_values: LocaleSiteSetting.values,
      translate_names: LocaleSiteSetting.translate_names?
    }
  end

  def refresh_site_locale!
    RailsMultisite::ConnectionManagement.each_connection do |db|
      @@site_locales[db] =
        if GlobalSetting.respond_to?(DEFAULT_LOCALE_KEY) &&
            (global_val = GlobalSetting.send(DEFAULT_LOCALE_KEY)) &&
            !global_val.blank?
          global_val
        elsif (db_val = @site_setting.provider.find(DEFAULT_LOCALE_KEY))
          db_val.value.to_s
        else
          DEFAULT_LOCALE
        end

      @@site_locales[db]
    end
  end

  def has_setting?(name)
    has_key?(name.to_sym) || has_key?("#{name.to_s}?".to_sym)
  end

  private

  def has_key?(name)
    @defaults[self.site_locale.to_sym]&.key?(name) ||
      @defaults[DEFAULT_LOCALE.to_sym].key?(name) || name == DEFAULT_LOCALE_KEY
  end

  def current_db
    RailsMultisite::ConnectionManagement.current_db
  end

end
