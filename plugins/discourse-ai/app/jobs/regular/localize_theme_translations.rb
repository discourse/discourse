# frozen_string_literal: true

module Jobs
  class LocalizeThemeTranslations < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      theme_id = args[:theme_id]
      raise Discourse::InvalidParameters.new(:theme_id) if theme_id.blank?

      theme = Theme.find_by(id: theme_id)
      return if theme.blank?

      target_locales = SiteSetting.content_localization_supported_locales.to_s.split("|")
      return if target_locales.empty?

      source_locale = args[:source_locale].presence || "en"
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
          translate_and_upsert(theme, key, text, locale)
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
      field = theme.theme_fields.find_by(target_id: Theme.targets[:translations], name: locale)
      return {} if field.blank?
      data = field.raw_translation_data[locale.to_sym] || {}
      ThemeTranslationManager
        .list_from_hash(locale: locale, hash: data, theme: theme)
        .each_with_object({}) { |tm, h| h[tm.key] = tm.default }
    end

    def translate_and_upsert(theme, key, text, locale)
      value =
        DiscourseAi::Translation::ShortTextTranslator.new(
          text: text,
          target_locale: locale,
        ).translate
      return if value.blank?

      record =
        ThemeTranslationOverride.find_or_initialize_by(
          theme_id: theme.id,
          locale: locale,
          translation_key: key,
        )
      record.value = value
      record.save!
    rescue FinalDestination::SSRFDetector::LookupFailedError
      # transient lookup failures
    rescue => e
      DiscourseAi::Translation::VerboseLogger.log(
        "Failed to translate theme #{theme.id} key #{key} to #{locale}: #{e.message}",
      )
    end
  end
end
