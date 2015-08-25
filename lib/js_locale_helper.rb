module JsLocaleHelper

  def self.load_translations(locale, opts=nil)
    opts ||= {}

    @loaded_translations = nil if opts[:force]

    @loaded_translations ||= HashWithIndifferentAccess.new
    @loaded_translations[locale] ||= begin
      locale_str = locale.to_s

      # load default translations
      translations = YAML::load(File.open("#{Rails.root}/config/locales/client.#{locale_str}.yml"))
      # load plugins translations
      plugin_translations = {}
      Dir["#{Rails.root}/plugins/*/config/locales/client.#{locale_str}.yml"].each do |file|
        plugin_translations.deep_merge! YAML::load(File.open(file))
      end

      # merge translations (plugin translations overwrite default translations)
      translations[locale_str]['js'].deep_merge!(plugin_translations[locale_str]['js']) if translations[locale_str] && plugin_translations[locale_str] && plugin_translations[locale_str]['js']

      # We used to split the admin versus the client side, but it's much simpler to just
      # include both for now due to the small size of the admin section.
      #
      # For now, let's leave it split out in the translation file in case we want to split
      # it again later, so we'll merge the JSON ourselves.
      admin_contents = translations[locale_str].delete('admin_js')
      translations[locale_str]['js'].deep_merge!(admin_contents) if admin_contents.present?
      translations[locale_str]['js'].deep_merge!(plugin_translations[locale_str]['admin_js']) if translations[locale_str] && plugin_translations[locale_str] && plugin_translations[locale_str]['admin_js']

      translations
    end
  end

  # purpose-built recursive algorithm ahoy!
  def self.deep_delete_matches(deleting_from, *checking_hashes)
    checking_hashes.compact!

    new_hash = deleting_from.dup
    deleting_from.each do |key, value|
      if value.is_a? Hash
        # Recurse
        new_at_key = deep_delete_matches(deleting_from[key], *(checking_hashes.map {|h| h[key]}))
        if new_at_key.empty?
          new_hash.delete key
        else
          new_hash[key] = new_at_key
        end
      else
        if checking_hashes.any? {|h| h.include? key}
          new_hash.delete key
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
        all_translations[locale] = JsLocaleHelper.load_translations locale
        merged_translations[locale] = deep_delete_matches(all_translations[locale][locale], *loaded_locales.map { |l| merged_translations[l] })
        loaded_locales << locale
      end
      merged_translations
    end
  end

  def self.output_locale(locale)
    locale_sym = locale.to_sym
    locale_str = locale.to_s

    current_locale = I18n.locale
    I18n.locale = locale_sym

    site_locale = SiteSetting.default_locale.to_sym

    if Rails.env.development?
      translations = load_translations(locale_sym, force: true)
    else
      if locale_sym == :en
        translations = load_translations(locale_sym)
      elsif locale_sym == site_locale || site_locale == :en
        translations = load_translations_merged(locale_sym, :en)
      else
        translations = load_translations_merged(locale_sym, site_locale, :en)
      end
    end

    message_formats = strip_out_message_formats!(translations[locale_str]['js'])

    result = generate_message_format(message_formats, locale_str)

    result << "I18n.translations = #{translations.to_json};\n"
    result << "I18n.locale = '#{locale_str}';\n"
    # loading moment here cause we must customize it
    result << File.read("#{Rails.root}/lib/javascripts/moment.js")
    result << moment_locale(locale_str)
    result << moment_formats

    I18n.locale = current_locale

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
    filename = Rails.root + "lib/javascripts/moment_locale/#{locale_str}.js"
    if File.exists?(filename)
      File.read(filename) << "\n"
    end || ""
  end

  def self.generate_message_format(message_formats, locale_str)
    formats = message_formats.map{|k,v| k.inspect << " : " << compile_message_format(locale_str ,v)}.join(" , ")

    result = "MessageFormat = {locale: {}};\n"

    filename = Rails.root + "lib/javascripts/locale/#{locale_str}.js"
    filename = Rails.root + "lib/javascripts/locale/en.js" unless File.exists?(filename)

    result << File.read(filename) << "\n"

    result << "I18n.messageFormat = (function(formats){
      var f = formats;
      return function(key, options) {
        var fn = f[key];
        if(fn){
          try {
            return fn(options);
          } catch(err) {
            return err.message;
          }
        } else {
          return 'Missing Key: ' + key
        }
        return f[key](options);
      };
    })({#{formats}});"
  end

  def self.compile_message_format(locale, format)
    ctx = V8::Context.new
    ctx.load(Rails.root + 'lib/javascripts/messageformat.js')
    path = Rails.root + "lib/javascripts/locale/#{locale}.js"
    ctx.load(path) if File.exists?(path)
    ctx.eval("mf = new MessageFormat('#{locale}');")
    ctx.eval("mf.precompile(mf.parse(#{format.inspect}))")

  rescue V8::Error => e
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
