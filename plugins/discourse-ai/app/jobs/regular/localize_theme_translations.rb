# frozen_string_literal: true

module Jobs
  class LocalizeThemeTranslations < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      theme_id = args[:theme_id]
      raise Discourse::InvalidParameters.new(:theme_id) if theme_id.blank?

      theme = Theme.includes(:theme_fields, :theme_translation_overrides).find_by(id: theme_id)
      return if theme.blank?

      source_locale = args[:source_locale].presence || "en"
      target_locales = SiteSetting.content_localization_supported_locales.to_s.split("|")
      target_locales &= Array(args[:target_locales]) if args.key?(:target_locales)
      return if target_locales.empty?

      override_existing = args[:override_existing] == true
      object_defaults = theme.object_translation_defaults(strict: false)
      defaults =
        load_yaml(theme, "en").merge(object_defaults.transform_values { |entry| entry[:text] })
      source_yaml = load_yaml(theme, source_locale)
      target_keys = target_locales.to_h { |locale| [locale, load_yaml(theme, locale).keys.to_set] }
      overrides =
        theme.theme_translation_overrides.index_by { |entry| [entry.locale, entry.translation_key] }

      defaults.each do |key, default_text|
        default_locale = object_defaults.dig(key, :locale) || "en"
        source =
          translation_source(
            key,
            source_locale,
            default_locale,
            default_text,
            yaml: source_yaml,
            overrides: overrides,
          )
        next if source.nil?

        locales = target_locales - [source[:locale]]
        locales -= [source_locale] unless object_defaults.key?(key)
        # Generate the selected locale last so our output cannot become a preferred source mid-run.
        locales = locales.sort_by { |locale| locale == source_locale ? 1 : 0 }
        locales.each do |locale|
          if !override_existing &&
               (
                 overrides.key?([locale, key]) || target_keys[locale].include?(key) ||
                   object_defaults.dig(key, :locale) == locale
               )
            next
          end
          translate_and_upsert(
            theme,
            key,
            source,
            locale,
            source_locale: source_locale,
            original_default: default_text,
            override_existing:,
          )
        end
      end
    end

    private

    def translation_source(key, source_locale, default_locale, default_text, yaml:, overrides:)
      [
        [source_locale, :override, overrides[[source_locale, key]]&.value],
        [source_locale, :yaml, yaml[key]],
        [default_locale, :override, overrides[[default_locale, key]]&.value],
        [default_locale, :default, default_text],
      ].each do |locale, type, text|
        if text.present?
          return { text: text, locale: locale, type: type, default_locale: default_locale }
        end
      end
      nil
    end

    def load_yaml(theme, locale)
      field =
        theme.theme_fields.find do |entry|
          entry.target_id == Theme.targets[:translations] && entry.name == locale
        end
      return {} if field.blank?
      data = field.raw_translation_data[locale.to_sym] || {}
      ThemeTranslationManager
        .list_from_hash(locale: locale, hash: data, theme: theme)
        .each_with_object({}) { |tm, h| h[tm.key] = tm.default }
    end

    def translate_and_upsert(
      theme,
      key,
      source,
      locale,
      source_locale:,
      original_default:,
      override_existing:
    )
      value =
        DiscourseAi::Translation::ShortTextTranslator.new(
          text: source[:text],
          target_locale: locale,
        ).translate
      return if value.blank?

      theme.with_lock do
        record =
          ThemeTranslationOverride.find_or_initialize_by(
            theme_id: theme.id,
            locale: locale,
            translation_key: key,
          )
        object_defaults = theme.object_translation_defaults(strict: false)
        if !override_existing &&
             (
               record.persisted? || load_yaml(theme, locale).key?(key) ||
                 object_defaults.dig(key, :locale) == locale
             )
          next
        end
        next if record.current_default != original_default
        next unless object_defaults.key?(key) || load_yaml(theme, "en").key?(key)
        current_source =
          translation_source(
            key,
            source_locale,
            object_defaults.dig(key, :locale) || "en",
            original_default,
            yaml: load_yaml(theme, source_locale),
            overrides:
              theme
                .theme_translation_overrides
                .where(translation_key: key)
                .index_by { |entry| [entry.locale, entry.translation_key] },
          )
        next if current_source != source
        record.value = value
        record.save!
      end
    rescue FinalDestination::SSRFDetector::LookupFailedError
      # transient lookup failures
    rescue => e
      DiscourseAi::Translation::VerboseLogger.log(
        "Failed to translate theme #{theme.id} key #{key} to #{locale}: #{e.message}",
      )
    end
  end
end
