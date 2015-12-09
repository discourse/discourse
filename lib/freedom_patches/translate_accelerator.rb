# This patch performs 2 functions
#
# 1. It caches all translations which drastically improves
#    translation performance in an LRU cache
#
# 2. It patches I18n so it only loads the translations it needs
#    on demand
#
# This patch depends on the convention that locale yml files must be named [locale_name].yml

module I18n

  # this accelerates translation a tiny bit (halves the time it takes)
  class << self
    alias_method :translate_no_cache, :translate
    alias_method :exists_no_cache?, :exists?
    alias_method :reload_no_cache!, :reload!
    LRU_CACHE_SIZE = 300

    def init_accelerator!
      @overrides_enabled = true
      reload!
    end

    def reload!
      @loaded_locales = []
      @cache = nil
      @overrides_by_site = {}

      reload_no_cache!
    end

    LOAD_MUTEX = Mutex.new
    def load_locale(locale)
      LOAD_MUTEX.synchronize do
        return if @loaded_locales.include?(locale)

        if @loaded_locales.empty?
          # load all rb files
          I18n.backend.load_translations(I18n.load_path.grep(/\.rb$/))
        end

        # load it
        I18n.backend.load_translations(I18n.load_path.grep Regexp.new("\\.#{locale}\\.yml$"))

        @loaded_locales << locale
      end
    end

    def ensure_all_loaded!
      backend.fallbacks(locale).each {|l| ensure_loaded!(l) }
    end

    def search(query, opts=nil)
      load_locale(config.locale) unless @loaded_locales.include?(config.locale)
      opts ||= {}

      target = opts[:backend] || backend
      results = opts[:overridden] ? {} : target.search(config.locale, query)

      regexp = /#{query}/i
      (overrides_by_locale || {}).each do |k, v|
        results.delete(k)
        results[k] = v if (k =~ regexp || v =~ regexp)
      end
      results
    end

    def ensure_loaded!(locale)
      @loaded_locales ||= []
      load_locale(locale) unless @loaded_locales.include?(locale)
    end

    # In some environments such as migrations we don't want to use overrides.
    # Use this to disable them over a block of ruby code
    def overrides_disabled
      @overrides_enabled = false
      yield
    ensure
      @overrides_enabled = true
    end

    def translate_no_override(key, *args)
      return translate_no_cache(key, *args) if args.length > 0

      @cache ||= LruRedux::ThreadSafeCache.new(LRU_CACHE_SIZE)
      k = "#{key}#{config.locale}#{config.backend.object_id}"

      @cache.getset(k) do
        translate_no_cache(key).freeze
      end
    end

    def overrides_by_locale
      return unless @overrides_enabled

      site = RailsMultisite::ConnectionManagement.current_db

      by_site = @overrides_by_site[site]

      by_locale = nil
      unless by_site
        by_site = @overrides_by_site[site] = {}

        # Load overrides
        TranslationOverride.where(locale: locale).pluck(:translation_key, :value).each do |tuple|
          by_locale = by_site[locale] ||= {}
          by_locale[tuple[0]] = tuple[1]
        end
      end

      by_site[config.locale]
    end

    def client_overrides_json
      client_json = (overrides_by_locale || {}).select {|k, _| k.starts_with?('js.') || k.starts_with?('admin_js.')}
      MultiJson.dump(client_json)
    end

    def translate(key, *args)
      load_locale(config.locale) unless @loaded_locales.include?(config.locale)

      if @overrides_enabled
        by_locale = overrides_by_locale
        if by_locale
          if args.size > 0 && args[0].is_a?(Hash)
            args[0][:overrides] = by_locale
            # I18n likes to use throw...
            catch(:exception) do
              return backend.translate(config.locale, key, args[0])
            end
          else
            if result = by_locale[key]
              return result
            end
          end

        end
      end
      translate_no_override(key, *args)
    end

    alias_method :t, :translate

    def exists?(*args)
      load_locale(config.locale) unless @loaded_locales.include?(config.locale)
      exists_no_cache?(*args)
    end

  end
end
