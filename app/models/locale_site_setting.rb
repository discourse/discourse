# frozen_string_literal: true

class LocaleSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    supported_locales.include?(val)
  end

  def self.values
    @values ||=
      supported_locales.map do |locale|
        lang = language_names[locale] || language_names[locale.split("_")[0]]
        { name: lang ? lang["nativeName"] : locale, value: locale }
      end
  end

  @lock = Mutex.new

  def self.language_names
    return @language_names if @language_names

    @lock.synchronize do
      @language_names ||=
        begin
          names = YAML.safe_load(File.read(File.join(Rails.root, "config", "locales", "names.yml")))

          DiscoursePluginRegistry.locales.each do |locale, options|
            if !names.key?(locale) && options[:name] && options[:nativeName]
              names[locale] = { "name" => options[:name], "nativeName" => options[:nativeName] }
            end
          end

          names
        end
    end
  end

  def self.supported_locales
    @lock.synchronize do
      @supported_locales ||=
        begin
          locales =
            Dir
              .glob(File.join(Rails.root, "config", "locales", "client.*.yml"))
              .map { |x| x.split(".")[-2] }

          locales += DiscoursePluginRegistry.locales.keys
          locales.uniq.sort
        end
    end
  end

  def self.reset!
    @lock.synchronize { @values = @language_names = @supported_locales = nil }
  end

  FALLBACKS = { en_GB: :en }

  def self.fallback_locale(locale)
    fallback_locale = FALLBACKS[locale.to_sym]
    return fallback_locale if fallback_locale

    plugin_locale = DiscoursePluginRegistry.locales[locale.to_s]
    plugin_locale ? plugin_locale[:fallbackLocale]&.to_sym : nil
  end
end
