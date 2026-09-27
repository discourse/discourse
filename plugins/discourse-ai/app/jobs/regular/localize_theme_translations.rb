# frozen_string_literal: true

module Jobs
  class LocalizeThemeTranslations < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      theme_id = args[:theme_id]
      raise Discourse::InvalidParameters.new(:theme_id) if theme_id.blank?

      theme = Theme.includes(:theme_fields).find_by(id: theme_id)
      return if theme.blank?

      source_locale = args[:source_locale].presence || "en"
      target_locales = SiteSetting.content_localization_supported_locales.to_s.split("|")
      target_locales &= Array(args[:target_locales]) if args.key?(:target_locales)
      target_locales -= [source_locale]
      return if target_locales.empty?

      override_existing = args[:override_existing] == true
      target_keys =
        target_locales.to_h do |locale|
          [locale, (load_yaml(theme, locale).keys + load_overrides(theme, locale).keys).to_set]
        end
      non_en_source = source_locale != "en"

      source_overrides = non_en_source ? load_overrides(theme, source_locale) : {}
      source_yaml = non_en_source ? load_yaml(theme, source_locale) : {}
      en_overrides = load_overrides(theme, "en")
      en_yaml = load_yaml(theme, "en")

      en_yaml.each_key do |key|
        if (text = source_overrides[key].presence || source_yaml[key].presence)
          effective_locale = source_locale
        elsif (text = en_overrides[key].presence || en_yaml[key].presence)
          effective_locale = "en"
        else
          next
        end

        (target_locales - [effective_locale]).each do |locale|
          next if !override_existing && target_keys[locale].include?(key)
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
        next unless load_yaml(theme, "en").key?(key)

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
