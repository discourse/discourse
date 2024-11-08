# frozen_string_literal: true

module JsLocaleHelper
  def self.plugin_client_files(locale_str)
    files = Dir["#{Rails.root}/plugins/*/config/locales/client*.#{locale_str}.yml"]
    I18n::Backend::DiscourseI18n.sort_locale_files(files)
  end

  def self.reloadable_plugins(locale_sym, ctx)
    return unless Rails.env.development?
    I18n.fallbacks[locale_sym].each do |locale|
      plugin_client_files(locale.to_s).each { |file| ctx.depend_on(file) }
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
        translations = { locale_str => { "js" => {}, "admin_js" => {}, "wizard_js" => {} } }
      end

      # merge translations (plugin translations overwrite default translations)
      if translations[locale_str] && plugin_translations(locale_str)
        translations[locale_str]["js"] ||= {}
        translations[locale_str]["admin_js"] ||= {}
        translations[locale_str]["wizard_js"] ||= {}

        if plugin_translations(locale_str)["js"]
          translations[locale_str]["js"].deep_merge!(plugin_translations(locale_str)["js"])
        end
        if plugin_translations(locale_str)["admin_js"]
          translations[locale_str]["admin_js"].deep_merge!(
            plugin_translations(locale_str)["admin_js"],
          )
        end
        if plugin_translations(locale_str)["wizard_js"]
          translations[locale_str]["wizard_js"].deep_merge!(
            plugin_translations(locale_str)["wizard_js"],
          )
        end
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
        new_hash.delete(key) if checking_hashes.any? { |h| h.include?(key) }
      end
    end
    new_hash
  end

  def self.load_translations_merged(*locales)
    locales = locales.uniq.compact
    @loaded_merges ||= {}
    @loaded_merges[locales.join("-")] ||= begin
      all_translations = {}
      merged_translations = {}
      loaded_locales = []

      locales
        .map(&:to_s)
        .each do |locale|
          all_translations[locale] = load_translations(locale)
          merged_translations[locale] = deep_delete_matches(
            all_translations[locale][locale],
            loaded_locales.map { |l| merged_translations[l] },
          )
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

  def self.translations_for(locale_str, no_fallback: false)
    clear_cache! if Rails.env.development?

    locale_sym = locale_str.to_sym

    translations =
      I18n.with_locale(locale_sym) do
        if locale_sym == :en || no_fallback
          load_translations(locale_sym)
        else
          load_translations_merged(*I18n.fallbacks[locale_sym])
        end
      end

    Marshal.load(Marshal.dump(translations))
  end

  def self.output_MF(locale)
    require "messageformat"

    message_formats =
      I18n.fallbacks[locale]
        .each_with_object(HashWithIndifferentAccess.new) do |l, hash|
          translations = translations_for(l, no_fallback: true)
          hash[l] = remove_message_formats!(translations, l).merge(
            TranslationOverride
              .mf_locales(l)
              .pluck(:translation_key, :value)
              .to_h
              .transform_keys { _1.sub(/^[a-z_]*js\./, "") },
          )
        end
        .compact_blank
    js_message_formats = message_formats.transform_keys(&:dasherize)
    compiled = MessageFormat.compile(js_message_formats.keys, js_message_formats, strict: false)
    transpiled = DiscourseJsProcessor.transpile(<<~JS, "", "discourse-mf")
      import Messages from '@messageformat/runtime/messages';
      #{compiled.sub("export default", "const msgData =")};
      const messages = new Messages(msgData, "#{locale.to_s.dasherize}");
      messages.defaultLocale = "en";
      globalThis.I18n._mfMessages = messages;
    JS
    <<~JS
      #{transpiled}
      require("discourse-mf");
    JS
  rescue => e
    js_locale = locale.to_s.dasherize
    message_formats[locale]
      .filter_map do |key, value|
        next if MessageFormat.compile(js_locale, value, strict: false)
      rescue StandardError
        key
      end
      .then do |strings|
        Rails.logger.error(
          "Failed to compile message formats for #{locale}.\n\nBroken strings are: #{strings.join(", ")}\n\nError: #{e}",
        )
      end
    <<~JS
      console.error("Failed to compile message formats for #{locale}. Some translation strings will be missing.");
    JS
  end

  def self.output_locale(locale)
    locale_str = locale.to_s
    fallback_locale_str = LocaleSiteSetting.fallback_locale(locale_str)&.to_s
    translations = translations_for(locale_str)

    remove_message_formats!(translations, locale)
    result = +""

    translations.keys.each do |l|
      translations[l].keys.each { |k| translations[l].delete(k) unless k == "js" }
    end

    # I18n
    result << "I18n.translations = #{translations.to_json};\n"
    result << "I18n.locale = '#{locale_str}';\n"
    if fallback_locale_str && fallback_locale_str != "en"
      result << "I18n.fallbackLocale = '#{fallback_locale_str}';\n"
    end

    # moment
    result << File.read("#{Rails.root}/vendor/assets/javascripts/moment.js")
    result << File.read("#{Rails.root}/vendor/assets/javascripts/moment-timezone-with-data.js")
    result << moment_locale(locale_str)
    result << moment_locale(locale_str, timezone_names: true)
    result << moment_formats

    result
  end

  def self.output_client_overrides(main_locale)
    locales = I18n.fallbacks[main_locale]
    all_overrides =
      locales
        .each_with_object({}) do |locale, overrides|
          overrides[locale] = TranslationOverride
            .client_locales(locale)
            .pluck(:translation_key, :value)
            .to_h
        end
        .compact_blank

    return "" if all_overrides.blank?

    all_overrides.reduce do |(_, main_overrides), (_, fallback_overrides)|
      fallback_overrides.slice!(*fallback_overrides.keys - main_overrides.keys)
    end

    "I18n._overrides = #{all_overrides.compact_blank.to_json};"
  end

  def self.output_extra_locales(bundle, locale)
    translations = translations_for(locale)
    locales = translations.keys

    locales.each do |l|
      translations[l].keys.each do |k|
        bundle_translations = translations[l].delete(k)
        translations[l].deep_merge!(bundle_translations) if k == bundle
      end
    end

    return "" if translations.blank?

    output = +"if (!I18n.extras) { I18n.extras = {}; }"
    locales.each do |l|
      translations_json = translations[l].to_json
      output << <<~JS
        if (!I18n.extras["#{l}"]) { I18n.extras["#{l}"] = {}; }
        Object.assign(I18n.extras["#{l}"], #{translations_json});
      JS
    end

    output
  end

  MOMENT_LOCALE_MAPPING = { "hy" => "hy-am", "ug" => "ug-cn" }.freeze

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
      locale.tr("_", "-").downcase
    end
  end

  def self.find_locale(locale_chain, path, type, fallback_to_english:)
    locale_chain.map!(&:to_s)

    locale_chain.each do |locale|
      plugin_locale = DiscoursePluginRegistry.locales[locale]
      return plugin_locale[type] if plugin_locale&.has_key?(type)

      locale = yield(locale) if block_given?
      filename = File.join(path, "#{locale}.js")
      return locale, filename if File.exist?(filename)
    end

    locale_chain.map! { |locale| yield(locale) } if block_given?

    # try again, but this time only with the language itself
    locale_chain =
      locale_chain.map { |l| l.split(/[-_]/)[0] }.uniq.reject { |l| locale_chain.include?(l) }

    if locale_chain.any?
      locale_data = find_locale(locale_chain, path, type, fallback_to_english: false)
      return locale_data if locale_data
    end

    # English should always work
    ["en", File.join(path, "en.js")] if fallback_to_english
  end

  def self.moment_formats
    result = +""
    result << moment_format_function("short_date_no_year")
    result << moment_format_function("short_date")
    result << moment_format_function("long_date")
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

  def self.remove_message_formats!(translations, locale)
    message_formats = {}
    I18n.fallbacks[locale]
      .map(&:to_s)
      .each do |l|
        next unless translations.key?(l)

        %w[js admin_js].each do |k|
          message_formats.merge!(strip_out_message_formats!(translations[l][k]))
        end
      end
    message_formats
  end

  def self.strip_out_message_formats!(hash, prefix = "", message_formats = {})
    if hash.is_a?(Hash)
      hash.each do |key, value|
        if value.is_a?(Hash)
          message_formats.merge!(
            strip_out_message_formats!(value, join_key(prefix, key), message_formats),
          )
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
