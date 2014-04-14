module I18n
  # this accelerates translation a tiny bit (halves the time it takes)
  class << self
    alias_method :translate_no_cache, :translate
    alias_method :reload_no_cache!, :reload!
    LRU_CACHE_SIZE = 2000

    def reload!
      @cache = nil
      reload_no_cache!
    end

    def translate(*args)
      @cache ||= LruRedux::ThreadSafeCache.new(LRU_CACHE_SIZE)
      found = true
      k = [args, config.locale, config.backend.object_id]
      t = @cache.fetch(k) { found = false }
      unless found
        begin
          t = translate_no_cache(*args)
        rescue MissingInterpolationArgument
          options = args.last.is_a?(Hash) ? args.pop.dup : {}
          options.merge!(locale: config.default_locale)
          key = args.shift
          t = translate_no_cache(key, options)
        ensure
          t = @cache[k] = t.freeze
        end
      end
      t
    end

    alias_method :t, :translate
  end
end
