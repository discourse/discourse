# frozen_string_literal: true

module SiteSettings
end

# A cache for providing default value based on site locale
class SiteSettings::DefaultsProvider
  DEFAULT_LOCALE = "en"

  def initialize(site_setting)
    @site_setting = site_setting
    @defaults = {}
    @defaults[DEFAULT_LOCALE.to_sym] = {}
    @active_upcoming_change_overrides = Set.new
  end

  def load_setting(name_arg, value, locale_defaults)
    name = name_arg.to_sym
    @defaults[DEFAULT_LOCALE.to_sym][name] = value

    if (locale_defaults)
      locale_defaults.each do |locale, v|
        locale = locale.to_sym
        @defaults[locale] ||= {}
        @defaults[locale][name] = v
      end
    end
  end

  def activate_upcoming_change_override(upcoming_change_setting)
    @active_upcoming_change_overrides.add(upcoming_change_setting.to_sym)
  end

  def deactivate_upcoming_change_override(upcoming_change_setting)
    @active_upcoming_change_overrides.delete(upcoming_change_setting.to_sym)
  end

  def db_all
    @site_setting.provider.all
  end

  # Defaults loaded from yaml files before mutation by upcoming
  # changes and modifiers.
  def all_clean(locale = nil)
    if locale
      @defaults[DEFAULT_LOCALE.to_sym].merge(@defaults[locale.to_sym] || {})
    else
      @defaults[DEFAULT_LOCALE.to_sym].dup
    end
  end

  def all(locale = nil, include_upcoming_changes_overrides: true)
    result = all_clean(locale)

    if include_upcoming_changes_overrides
      # Only support upcoming change default overrides on default locale for now,
      # we can come back to this later if we need the extra complexity.
      @site_setting.upcoming_change_default_overrides.each do |setting_name, override|
        result[setting_name] = override[:new_default] if @active_upcoming_change_overrides.include?(
          override[:upcoming_change],
        )
      end
    end

    DiscoursePluginRegistry.apply_modifier(:site_setting_defaults, result)
  end

  def upcoming_change_override_metadata(setting_name)
    upcoming_change_default_override =
      @site_setting.upcoming_change_default_overrides[setting_name.to_sym]

    if upcoming_change_default_override.blank? ||
         !@active_upcoming_change_overrides.include?(
           upcoming_change_default_override[:upcoming_change],
         )
      return
    end

    {
      old_default: all_clean[setting_name].to_s,
      new_default: upcoming_change_default_override[:new_default].to_s,
      change_setting_name: upcoming_change_default_override[:upcoming_change].to_sym,
    }
  end

  def get(name, locale = DEFAULT_LOCALE)
    all(locale)[name.to_sym]
  end
  alias [] get

  # Used to override site settings in dev/test env
  def set_regardless_of_locale(name, value)
    name = name.to_sym
    if name == :default_locale || @site_setting.has_setting?(name)
      @defaults.each { |_, hash| hash.delete(name) }
      @defaults[DEFAULT_LOCALE.to_sym][name] = value
      value, type = @site_setting.type_supervisor.to_db_value(name, value)
      @defaults[SiteSetting.default_locale.to_sym] ||= {}
      @defaults[SiteSetting.default_locale.to_sym][
        name
      ] = @site_setting.type_supervisor.to_rb_value(name, value, type)
    else
      raise ArgumentError.new("No setting named '#{name}' exists")
    end
  end

  def has_setting?(name)
    has_key?(name.to_sym) || has_key?("#{name}?".to_sym) || name.to_sym == :default_locale
  end

  private

  def has_key?(name)
    @defaults[DEFAULT_LOCALE.to_sym].key?(name)
  end

  def current_db
    RailsMultisite::ConnectionManagement.current_db
  end
end
