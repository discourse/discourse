# frozen_string_literal: true

module JsLocaleHelper

  def self.plugin_client_files(locale_str)
    Dir["#{Rails.root}/plugins/*/config/locales/client.#{locale_str}.yml"]
  end

  def self.reloadable_plugins(locale, ctx)
    return unless Rails.env.development?
    plugin_client_files(locale.to_s).each do |file|
      ctx.depend_on(file)
    end
  end

  def self.plugin_translations(locale_str)
    @plugin_translations ||= HashWithIndifferentAccess.new

    @plugin_translations[locale_str] ||= begin
      translations = {}

      plugin_client_files(locale_str).each do |file|
        if plugin_translations = YAML.load_file(file)[locale_str]
          translations.deep_merge!(plugin_translations)
        end
      end

      translations
    end
  end

  def self.load_translations(locale)
    @loaded_translations ||= HashWithIndifferentAccess.new
    @loaded_translations[locale] ||= begin
      locale_str = locale.to_s

      # load default translations
      yml_file = "#{Rails.root}/config/locales/client.#{locale_str}.yml"
      if File.exist?(yml_file)
        translations = YAML.load_file(yml_file)
      else
        # If we can't find a base file in Discourse, it might only exist in a plugin
        # so let's start with a basic object we can merge into
        translations = {
          locale_str => {
            'js' => {},
            'admin_js' => {},
            'wizard_js' => {}
          }
        }
      end

      # merge translations (plugin translations overwrite default translations)
      if translations[locale_str] && plugin_translations(locale_str)
        translations[locale_str]['js'] ||= {}
        translations[locale_str]['admin_js'] ||= {}
        translations[locale_str]['wizard_js'] ||= {}

        translations[locale_str]['js'].deep_merge!(plugin_translations(locale_str)['js']) if plugin_translations(locale_str)['js']
        translations[locale_str]['admin_js'].deep_merge!(plugin_translations(locale_str)['admin_js']) if plugin_translations(locale_str)['admin_js']
        translations[locale_str]['wizard_js'].deep_merge!(plugin_translations(locale_str)['wizard_js']) if plugin_translations(locale_str)['wizard_js']
      end

      translations
    end
  end

  # deeply removes keys from "deleting_from" that are already present in "checking_hashes"
  def self.deep_delete_matches(deleting_from, checking_hashes)
    checking_hashes.compact!

    new_hash = deleting_from.dup
    deleting_from.each do |key, value|
      if value.is_a?(Hash)
        new_at_key = deep_delete_matches(deleting_from[key], checking_hashes.map { |h| h[key] })
        if new_at_key.empty?
          new_hash.delete(key)
        else
          new_hash[key] = new_at_key
        end
      else
        if checking_hashes.any? { |h| h.include?(key) }
          new_hash.delete(key)
        end
      end
    end
    new_hash
  end

  def self.load_translations_merged(*locales)
    locales = locales.uniq.compact
    @loaded_merges ||= {}
    @loaded_merges[locales.join('-')] ||= begin
      all_translations = {}
      merged_translations = {}
      loaded_locales = []

      locales.map(&:to_s).each do |locale|
        all_translations[locale] = load_translations(locale)
        merged_translations[locale] = deep_delete_matches(all_translations[locale][locale], loaded_locales.map { |l| merged_translations[l] })
        loaded_locales << locale
      end
      merged_translations
    end
  end

  def self.clear_cache!
    @loaded_translations = nil
    @plugin_translations = nil
    @loaded_merges = nil
  end

  def self.translations_for(locale_str)
    clear_cache! if Rails.env.development?

    locale_sym = locale_str.to_sym

    translations = I18n.with_locale(locale_sym) do
      if locale_sym == :en
        load_translations(locale_sym)
      else
        load_translations_merged(*I18n.fallbacks[locale_sym])
      end
    end

    Marshal.load(Marshal.dump(translations))
  end

  def self.output_locale(locale)
    locale_str = locale.to_s
    fallback_locale_str = LocaleSiteSetting.fallback_locale(locale_str)&.to_s
    translations = translations_for(locale_str)

    message_formats = remove_message_formats!(translations, locale)
    mf_locale, mf_filename = find_message_format_locale([locale_str], fallback_to_english: true)
    result = generate_message_format(message_formats, mf_locale, mf_filename)

    translations.keys.each do |l|
      translations[l].keys.each do |k|
        translations[l].delete(k) unless k == "js"
      end
    end

    # I18n
    result << "I18n.translations = #{translations.to_json};\n"
    result << "I18n.locale = '#{locale_str}';\n"
    result << "I18n.fallbackLocale = '#{fallback_locale_str}';\n" if fallback_locale_str && fallback_locale_str != "en"
    result << "I18n.pluralizationRules.#{locale_str} = MessageFormat.locale.#{mf_locale};\n" if mf_locale != "en"

    # moment
    result << File.read("#{Rails.root}/vendor/assets/javascripts/moment.js")
    result << File.read("#{Rails.root}/vendor/assets/javascripts/moment-timezone-with-data.js")
    result << moment_locale(locale_str)
    result << moment_locale(locale_str, timezone_names: true)
    result << moment_formats

    result
  end

  MOMENT_LOCALE_MAPPING ||= {
    "hy" => "hy-am",
    "en" => "en-gb"
  }

  def self.find_moment_locale(locale_chain, timezone_names: false)
    if timezone_names
      path = "#{Rails.root}/vendor/assets/javascripts/moment-timezone-names-locale"
      type = :moment_js_timezones
    else
      path = "#{Rails.root}/vendor/assets/javascripts/moment-locale"
      type = :moment_js
    end

    find_locale(locale_chain, path, type, fallback_to_english: false) do |locale|
      locale = MOMENT_LOCALE_MAPPING[locale] if MOMENT_LOCALE_MAPPING.key?(locale)
      # moment.js uses a different naming scheme for locale files
      locale.tr('_', '-').downcase
    end

  end

  def self.find_message_format_locale(locale_chain, fallback_to_english:)
    path = "#{Rails.root}/lib/javascripts/locale"
    find_locale(locale_chain, path, :message_format, fallback_to_english: fallback_to_english)
  end

  def self.find_locale(locale_chain, path, type, fallback_to_english:)
    locale_chain.map!(&:to_s)

    locale_chain.each do |locale|
      plugin_locale = DiscoursePluginRegistry.locales[locale]
      return plugin_locale[type] if plugin_locale&.has_key?(type)

      locale = yield(locale) if block_given?
      filename = File.join(path, "#{locale}.js")
      return [locale, filename] if File.exist?(filename)
    end

    locale_chain.map! { |locale| yield(locale) } if block_given?

    # try again, but this time only with the language itself
    locale_chain = locale_chain.map { |l| l.split(/[-_]/)[0] }
      .uniq.reject { |l| locale_chain.include?(l) }

    if locale_chain.any?
      locale_data = find_locale(locale_chain, path, type, fallback_to_english: false)
      return locale_data if locale_data
    end

    # English should alyways work
    ["en", File.join(path, "en.js")] if fallback_to_english
  end

  def self.moment_formats
    result = +""
    result << moment_format_function('short_date_no_year')
    result << moment_format_function('short_date')
    result << moment_format_function('long_date')
    result << "moment.fn.relativeAge = function(opts){ return Discourse.Formatter.relativeAge(this.toDate(), opts)};\n"
  end

  def self.moment_format_function(name)
    format = I18n.t("dates.#{name}")
    "moment.fn.#{name.camelize(:lower)} = function(){ return this.format('#{format}'); };\n"
  end

  def self.moment_locale(locale, timezone_names: false)
    _, filename = find_moment_locale([locale], timezone_names: timezone_names)
    filename && File.exist?(filename) ? File.read(filename) << "\n" : ""
  end

  def self.generate_message_format(message_formats, locale, filename)
    formats = message_formats.map { |k, v| k.inspect << " : " << compile_message_format(filename, locale, v) }.join(", ")

    result = +"MessageFormat = {locale: {}};\n"
    result << "I18n._compiledMFs = {#{formats}};\n"
    result << File.read(filename) << "\n"
    result << File.read("#{Rails.root}/lib/javascripts/messageformat-lookup.js") << "\n"
  end

  def self.reset_context
    @ctx&.dispose
    @ctx = nil
  end

  @mutex = Mutex.new
  def self.with_context
    @mutex.synchronize do
      yield @ctx ||= begin
        ctx = MiniRacer::Context.new(timeout: 15000)
        ctx.load("#{Rails.root}/lib/javascripts/messageformat.js")
        ctx
      end
    end
  end

  def self.compile_message_format(path, locale, format)
    with_context do |ctx|
      ctx.load(path) if File.exist?(path)
      ctx.eval("mf = new MessageFormat('#{locale}');")
      ctx.eval("mf.precompile(mf.parse(#{format.inspect}))")
    end
  rescue MiniRacer::EvalError => e
    message = +"Invalid Format: " << e.message
    "function(){ return #{message.inspect};}"
  end

  def self.remove_message_formats!(translations, locale)
    message_formats = {}
    I18n.fallbacks[locale].map(&:to_s).each do |l|
      next unless translations.key?(l)

      %w{js admin_js}.each do |k|
        message_formats.merge!(strip_out_message_formats!(translations[l][k]))
      end
    end
    message_formats
  end

  def self.strip_out_message_formats!(hash, prefix = "", message_formats = {})
    if hash.is_a?(Hash)
      hash.each do |key, value|
        if value.is_a?(Hash)
          message_formats.merge!(strip_out_message_formats!(value, join_key(prefix, key), message_formats))
        elsif key.to_s.end_with?("_MF")
          message_formats[join_key(prefix, key)] = value
          hash.delete(key)
        end
      end
    end
    message_formats
  end

  def self.join_key(prefix, key)
    prefix.blank? ? key : "#{prefix}.#{key}"
  end
end
