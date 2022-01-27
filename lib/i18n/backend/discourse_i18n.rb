# frozen_string_literal: true

require 'i18n/backend/pluralization'

module I18n
  module Backend
    class DiscourseI18n < I18n::Backend::Simple
      include I18n::Backend::Fallbacks
      include I18n::Backend::Pluralization

      def available_locales
        LocaleSiteSetting.supported_locales.map(&:to_sym)
      end

      def reload!
        @pluralizers = {}
        # this calls `reload!` in our patch lib/freedom_patches/translate_accelerator.rb
        I18n.reload!
        super
      end

      # force explicit loading
      def load_translations(*filenames)
        unless filenames.empty?
          self.class.sort_locale_files(filenames.flatten).each do |filename|
            load_file(filename)
          end
        end
      end

      def pluralize(locale, entry, count)
        begin
          super
        rescue I18n::InvalidPluralizationData => e
          raise e if I18n.fallbacks[locale] == [locale]
          throw(:exception, e)
        end
      end

      def self.sort_locale_files(files)
        files.sort.sort_by do |filename|
          matches = /(?:client|server)-([1-9]|[1-9][0-9]|100)\..+\.yml/.match(filename)
          matches&.[](1)&.to_i || 0
        end
      end

      def self.create_search_regexp(query, as_string: false)
        regexp = Regexp.escape(query)

        regexp.gsub!(/['‘’‚‹›]/, "['‘’‚‹›]")
        regexp.gsub!(/["“”„«»]/, '["“”„«»]')
        regexp.gsub!(/(?:\\\.\\\.\\\.|…)/, '(?:\.\.\.|…)')

        as_string ? regexp : /#{regexp}/i
      end

      def search(locale, query)
        regexp = self.class.create_search_regexp(query)
        find_results(regexp, {}, translations[locale])
      end

      protected

      def find_results(regexp, results, translations, path = nil)
        return results if translations.blank?

        translations.each do |k_sym, v|
          k = k_sym.to_s
          key_path = path ? "#{path}.#{k}" : k
          if v.is_a?(String)
            unless results.has_key?(key_path)
              results[key_path] = v if key_path =~ regexp || v =~ regexp
            end
          elsif v.is_a?(Hash)
            find_results(regexp, results, v, key_path)
          end
        end
        results
      end

      # Support interpolation and pluralization of overrides by first looking up
      # the original translations before applying our overrides.
      def lookup(locale, key, scope = [], options = {})
        existing_translations = super(locale, key, scope, options)
        return existing_translations if scope.is_a?(Array) && scope.include?(:models)

        overrides = options.dig(:overrides, locale)
        key = key.to_s

        if overrides
          if options[:count]
            if !existing_translations
              I18n.fallbacks[locale].drop(1).each do |fallback|
                existing_translations = super(fallback, key, scope, options)
                break if existing_translations.present?
              end
            end

            if existing_translations
              remapped_translations =
                if existing_translations.is_a?(Hash)
                  Hash[existing_translations.map { |k, v| ["#{key}.#{k}", v] }]
                elsif existing_translations.is_a?(String)
                  Hash[[[key, existing_translations]]]
                end

              result = {}

              remapped_translations.merge(overrides).each do |k, v|
                result[k.split('.').last.to_sym] = v if k != key && k.start_with?(key)
              end
              return result if result.size > 0
            end
          end

          return overrides[key] if overrides[key]
        end

        existing_translations
      end
    end
  end
end
