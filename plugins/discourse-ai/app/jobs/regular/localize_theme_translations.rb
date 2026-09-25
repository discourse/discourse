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
      target_locales -= [source_locale]
      return if target_locales.empty?

      override_existing = args[:override_existing] == true
      object_defaults = theme.object_translation_defaults
      defaults =
        load_yaml(theme, "en").merge(object_defaults.transform_values { |entry| entry[:text] })
      source_yaml = load_yaml(theme, source_locale)
      source_overrides = load_overrides(theme, source_locale)
      target_keys = target_locales.to_h { |locale| [locale, load_yaml(theme, locale).keys.to_set] }
      overrides =
        theme.theme_translation_overrides.index_by { |entry| [entry.locale, entry.translation_key] }

      defaults.each do |key, default_text|
        default_locale = object_defaults.dig(key, :locale) || "en"
        text = source_overrides[key] || source_yaml[key]
        effective_locale = source_locale
        if text.nil?
          text = overrides[[default_locale, key]]&.value || default_text
          effective_locale = default_locale
        end
        next if text.blank?

        (target_locales - [effective_locale]).each do |locale|
          if !override_existing &&
               (overrides.key?([locale, key]) || target_keys[locale].include?(key))
            next
          end
          translate_and_upsert(theme, key, text, locale, override_existing:)
        end
      end
    end

    private

    def load_overrides(theme, locale)
      ThemeTranslationOverride
        .where(theme_id: theme.id, locale: locale)
        .pluck(:translation_key, :value)
        .to_h
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

    def translate_and_upsert(theme, key, text, locale, override_existing:)
      value =
        DiscourseAi::Translation::ShortTextTranslator.new(
          text: text,
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
        next if !override_existing && (record.persisted? || load_yaml(theme, locale).key?(key))
        next unless theme.translations.any? { |entry| entry.key == key }
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
