# frozen_string_literal: true

module DiscourseAi
  module Translation
    class SiteSettingLocalizer
      def self.localize(
        setting_name,
        target_locale = I18n.locale,
        short_text_llm_model: nil,
        post_raw_llm_model: nil
      )
        setting_name = setting_name.to_s
        return if setting_name.blank? || target_locale.blank?
        return if !SiteSettingLocalization.automatically_localizable?(setting_name)
        return if LocaleNormalizer.is_same?(SiteSetting.default_locale, target_locale)

        value = SiteSetting.public_send(setting_name)
        return if value.blank?

        target_locale = SiteSettingLocalization.normalize_locale(target_locale)
        translated_value =
          if SiteSettingLocalization.localizable_settings.dig(setting_name, :cooked)
            PostRawTranslator.new(
              text: value,
              target_locale:,
              llm_model: post_raw_llm_model,
            ).translate
          else
            ShortTextTranslator.new(
              text: value,
              target_locale:,
              llm_model: short_text_llm_model,
            ).translate
          end
        return if translated_value.blank?

        localization =
          SiteSettingLocalization.find_or_initialize_by(setting_name:, locale: target_locale)
        localization.value = translated_value
        localization.localizer_user_id = Discourse::SYSTEM_USER_ID
        localization.save!
        localization
      end
    end
  end
end
