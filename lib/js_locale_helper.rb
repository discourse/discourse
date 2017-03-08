module JsLocaleHelper

  def self.plugin_translations(locale_str)
    @plugin_translations ||= HashWithIndifferentAccess.new

    @plugin_translations[locale_str] ||= begin
      translations = {}

      Dir["#{Rails.root}/plugins/*/config/locales/client.#{locale_str}.yml"].each do |file|
        if plugin_translations = YAML.load_file(file)[locale_str]
          translations.deep_merge!(plugin_translations)
        end
      end

      translations
    end
  end

  def self.load_translations(locale, opts=nil)
    opts ||= {}

    @loaded_translations = nil if opts[:force]

    @loaded_translations ||= HashWithIndifferentAccess.new
    @loaded_translations[locale] ||= begin
      locale_str = locale.to_s

      # load default translations
      translations = YAML.load_file("#{Rails.root}/config/locales/client.#{locale_str}.yml")

      # merge translations (plugin translations overwrite default translations)
      translations[locale_str]['js'].deep_merge!(plugin_translations(locale_str)['js']) if translations[locale_str] && plugin_translations(locale_str) && plugin_translations(locale_str)['js']

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

  def self.translations_for(locale_str)
    current_locale = I18n.locale
    locale_sym     = locale_str.to_sym
    site_locale    = SiteSetting.default_locale.to_sym

    I18n.locale = locale_sym

    translations =
      if Rails.env.development?
        load_translations(locale_sym, force: true)
      elsif locale_sym == :en
        load_translations(locale_sym)
      elsif locale_sym == site_locale || site_locale == :en
        load_translations_merged(locale_sym, :en)
      else
        load_translations_merged(locale_sym, site_locale, :en)
      end

    I18n.locale = current_locale

    translations
  end

  def self.output_locale(locale)
    locale_str = locale.to_s
    translations = Marshal.load(Marshal.dump(translations_for(locale_str)))

    translations.keys.each do |locale|
      translations[locale].keys.each do |k|
        translations[locale].delete(k) unless k == "js"
      end
    end

    message_formats = strip_out_message_formats!(translations[locale_str]['js'])
    result = generate_message_format(message_formats, locale_str)

    # I18n
    result << "I18n.translations = #{translations.to_json};\n"
    result << "I18n.locale = '#{locale_str}';\n"
    result << "I18n.pluralizationRules.#{locale_str} = MessageFormat.locale.#{locale_str};\n" if locale_str != "en"

    # moment
    result << File.read("#{Rails.root}/lib/javascripts/moment.js")
    result << moment_locale(locale_str)
    result << moment_formats

    result
  end

  def self.moment_formats
    result = ""
    result << moment_format_function('short_date_no_year')
    result << moment_format_function('short_date')
    result << moment_format_function('long_date')
    result << "moment.fn.relativeAge = function(opts){ return Discourse.Formatter.relativeAge(this.toDate(), opts)};\n"
  end

  def self.moment_format_function(name)
    format = I18n.t("dates.#{name}")
    "moment.fn.#{name.camelize(:lower)} = function(){ return this.format('#{format}'); };\n"
  end

  def self.moment_locale(locale_str)
    # moment.js uses a different naming scheme for locale files
    locale_str = locale_str.tr('_', '-').downcase
    filename = "#{Rails.root}/lib/javascripts/moment_locale/#{locale_str}.js"

    # try the language without the territory
    locale_str = locale_str.split("-")[0]
    filename = "#{Rails.root}/lib/javascripts/moment_locale/#{locale_str}.js" unless File.exists?(filename)

    File.exists?(filename) ? File.read(filename) << "\n" : ""
  end

  def self.generate_message_format(message_formats, locale_str)
    formats = message_formats.map { |k,v| k.inspect << " : " << compile_message_format(locale_str, v) }.join(", ")

    filename = "#{Rails.root}/lib/javascripts/locale/#{locale_str}.js"
    filename = "#{Rails.root}/lib/javascripts/locale/en.js" unless File.exists?(filename)

    result = "MessageFormat = {locale: {}};\n"
    result << "I18n._compiledMFs = {#{formats}};\n"
    result << File.read(filename) << "\n"
    result << File.read("#{Rails.root}/lib/javascripts/messageformat-lookup.js") << "\n"
  end

  def self.reset_context
    @ctx = nil
  end

  @mutex = Mutex.new
  def self.with_context
    @mutex.synchronize do
      yield @ctx ||= begin
               ctx = MiniRacer::Context.new
               ctx.load("#{Rails.root}/lib/javascripts/messageformat.js")
               ctx
             end
    end
  end

  def self.compile_message_format(locale, format)
    with_context do |ctx|
      path = "#{Rails.root}/lib/javascripts/locale/#{locale}.js"
      ctx.load(path) if File.exists?(path)
      ctx.eval("mf = new MessageFormat('#{locale}');")
      ctx.eval("mf.precompile(mf.parse(#{format.inspect}))")
    end
  rescue MiniRacer::EvalError => e
    message = "Invalid Format: " << e.message
    "function(){ return #{message.inspect};}"
  end

  def self.strip_out_message_formats!(hash, prefix = "", rval = {})
    if hash.is_a?(Hash)
      hash.each do |key, value|
        if value.is_a?(Hash)
          rval.merge!(strip_out_message_formats!(value, prefix + (prefix.length > 0 ? "." : "") << key, rval))
        elsif key.to_s.end_with?("_MF")
          rval[prefix + (prefix.length > 0 ? "." : "") << key] = value
          hash.delete(key)
        end
      end
    end
    rval
  end

end
