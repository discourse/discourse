# frozen_string_literal: true

module Jobs
  class LocalizeThemeTranslations < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      theme_id = args[:theme_id]
      raise Discourse::InvalidParameters.new(:theme_id) if theme_id.blank?

      theme = Theme.find_by(id: theme_id)
      return if theme.blank?

      en_field = theme.theme_fields.find_by(target_id: Theme.targets[:translations], name: "en")
      return if en_field.blank?

      en_data = en_field.raw_translation_data[:en] || {}
      translations =
        ThemeTranslationManager.list_from_hash(locale: "en", hash: en_data, theme: theme)
      return if translations.blank?

      locales = SiteSetting.content_localization_supported_locales.to_s.split("|") - ["en"]
      return if locales.empty?

      locales.each do |locale|
        translations.each do |tm|
          begin
            value =
              DiscourseAi::Translation::ShortTextTranslator.new(
                text: tm.default,
                target_locale: locale,
              ).translate
            next if value.blank?

            ThemeTranslationOverride.upsert(
              {
                theme_id: theme.id,
                locale: locale,
                translation_key: tm.key,
                value: value,
                created_at: Time.now,
                updated_at: Time.now,
              },
              unique_by: %i[theme_id locale translation_key],
            )
          rescue FinalDestination::SSRFDetector::LookupFailedError
            # transient lookup failures
          rescue => e
            DiscourseAi::Translation::VerboseLogger.log(
              "Failed to translate theme #{theme.id} key #{tm.key} to #{locale}: #{e.message}",
            )
          end
        end
      end
    end
  end
end
