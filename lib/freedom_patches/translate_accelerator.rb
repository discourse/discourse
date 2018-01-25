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
      ensure_all_loaded!
    end

    LOAD_MUTEX = Mutex.new
    def load_locale(locale)
      LOAD_MUTEX.synchronize do
        return if @loaded_locales.include?(locale)

        if @loaded_locales.empty?
          # load all rb files
          I18n.backend.load_translations(I18n.load_path.grep(/\.rb$/))

          # load plural rules from plugins
          DiscoursePluginRegistry.locales.each do |locale, options|
            if options[:plural]
              I18n.backend.store_translations(locale, i18n: { plural: options[:plural] })
            end
          end
        end

        # load it
        I18n.backend.load_translations(I18n.load_path.grep(/\.#{Regexp.escape locale}\.yml$/))

        @loaded_locales << locale
      end
    end

    def ensure_all_loaded!
      backend.fallbacks(locale).each { |l| ensure_loaded!(l) }
    end

    def search(query, opts = nil)
      locale = opts[:locale] || config.locale

      load_locale(locale) unless @loaded_locales.include?(locale)
      opts ||= {}

      target = opts[:backend] || backend
      results = opts[:overridden] ? {} : target.search(config.locale, query)

      regexp = /#{query}/i
      (overrides_by_locale(locale) || {}).each do |k, v|
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

    def translate_no_override(*args)
      return translate_no_cache(*args) if args.length > 1 && args[1].present?

      options  = args.last.is_a?(Hash) ? args.pop.dup : {}
      key      = args.shift
      locale   = options[:locale] || config.locale

      @cache ||= LruRedux::ThreadSafeCache.new(LRU_CACHE_SIZE)
      k = "#{key}#{locale}#{config.backend.object_id}"

      @cache.getset(k) do
        translate_no_cache(key, options).freeze
      end
    end

    def overrides_by_locale(locale)
      return unless @overrides_enabled

      site = RailsMultisite::ConnectionManagement.current_db

      by_site = @overrides_by_site[site]
      by_site ||= {}

      if !by_site.has_key?(locale)
        # Load overrides
        translations_overrides = TranslationOverride.where(locale: locale).pluck(:translation_key, :value, :compiled_js)

        if translations_overrides.empty?
          by_site[locale] = {}
        else
          translations_overrides.each do |tuple|
            by_locale = by_site[locale] ||= {}
            by_locale[tuple[0]] = tuple[2] || tuple[1]
          end
        end

        @overrides_by_site[site] = by_site
      end

      by_site[locale].with_indifferent_access
    end

    def client_overrides_json(locale)
      client_json = (overrides_by_locale(locale) || {}).select { |k, _| k[/^(admin_js|js)\./] }
      MultiJson.dump(client_json)
    end

    def translate(*args)
      options  = args.last.is_a?(Hash) ? args.pop.dup : {}
      key      = args.shift
      locale   = options[:locale] || config.locale

      load_locale(locale) unless @loaded_locales.include?(locale)

      if @overrides_enabled
        overrides = {}

        backend.fallbacks(locale).each do |l|
          overrides[l] = overrides_by_locale(l)
        end

        if overrides.present?
          if options.present?
            options[:overrides] = overrides

            # I18n likes to use throw...
            catch(:exception) do
              return backend.translate(locale, key, options)
            end
          else
            overrides.each do |_k, v|
              if result = v[key]
                return result
              end
            end
          end
        end
      end

      translate_no_override(key, options)
    end

    alias_method :t, :translate

    def exists?(key, locale = nil)
      locale ||= config.locale
      load_locale(locale) unless @loaded_locales.include?(locale)
      exists_no_cache?(key, locale)
    end

  end
end
