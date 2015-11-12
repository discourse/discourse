require 'i18n/backend/pluralization'

module I18n
  module Backend
    class DiscourseI18n < I18n::Backend::Simple
      include I18n::Backend::Fallbacks
      include I18n::Backend::Pluralization

      def available_locales
        # in case you are wondering this is:
        # Dir.glob( File.join(Rails.root, 'config', 'locales', 'client.*.yml') )
        #    .map {|x| x.split('.')[-2]}.sort
        LocaleSiteSetting.supported_locales.map(&:to_sym)
      end

      def reload!
        @overrides = {}
        super
      end

      # force explicit loading
      def load_translations(*filenames)
        unless filenames.empty?
          filenames.flatten.each { |filename| load_file(filename) }
        end
      end

      def fallbacks(locale)
        [locale, SiteSetting.default_locale.to_sym, :en].uniq.compact
      end

      def exists?(locale, key)
        fallbacks(locale).each do |fallback|
          begin
            return true if super(fallback, key)
          rescue I18n::InvalidLocale
            # we do nothing when the locale is invalid, as this is a fallback anyways.
          end
        end

        false
      end

      protected

        def lookup(locale, key, scope = [], options = {})
          # Support interpolation and pluralization of overrides
          if options[:overrides]
            if options[:count]
              result = {}
              options[:overrides].each do |k, v|
                result[k.split('.').last.to_sym] = v if k != key && k.start_with?(key.to_s)
              end
              return result if result.size > 0
            end

            return options[:overrides][key] if options[:overrides][key]
          end

          super(locale, key, scope, options)
        end

    end
  end
end
