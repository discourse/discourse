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
  module Backend

    class Simple
      def available_locales
        # in case you are wondering this is:
        # Dir.glob( File.join(Rails.root, 'config', 'locales', 'client.*.yml') )
        #    .map {|x| x.split('.')[-2]}.sort
        LocaleSiteSetting.supported_locales.map(&:to_sym)
      end
    end

    module Base
      # force explicit loading
      def load_translations(*filenames)
        unless filenames.empty?
          filenames.flatten.each { |filename| load_file(filename) }
        end
      end

    end
  end
  # this accelerates translation a tiny bit (halves the time it takes)
  class << self
    alias_method :translate_no_cache, :translate
    alias_method :reload_no_cache!, :reload!
    LRU_CACHE_SIZE = 300

    def reload!
      @loaded_locales = []
      @cache = nil
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

    def ensure_loaded!(locale)
      @loaded_locales ||= []
      load_locale locale unless @loaded_locales.include?(locale)
    end

    def translate(key, *args)
      load_locale(config.locale) unless @loaded_locales.include?(config.locale)
      return translate_no_cache(key, *args) if args.length > 0

      @cache ||= LruRedux::ThreadSafeCache.new(LRU_CACHE_SIZE)
      k = "#{key}#{config.locale}#{config.backend.object_id}"

      @cache.getset(k) do
        translate_no_cache(key).freeze
      end
    end

    alias_method :t, :translate
  end
end
