# frozen_string_literal: true

module Jobs
  class LocalizeSiteSettings < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(args)
      return if !DiscourseAi::Translation.enabled?

      unless DiscourseAi::Translation.credits_available_for_site_setting_localization?
        Rails.logger.info(
          "Translation skipped for site settings: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      limit = args[:limit]
      raise Discourse::InvalidParameters.new(:limit) if limit.nil?
      return if limit <= 0

      short_text_llm_model =
        DiscourseAi::Translation.llm_model_for_agent(
          SiteSetting.ai_translation_short_text_translator_agent,
        )
      post_raw_llm_model =
        DiscourseAi::Translation.llm_model_for_agent(
          SiteSetting.ai_translation_post_raw_translator_agent,
        )
      return if short_text_llm_model.blank? && post_raw_llm_model.blank?

      source_locale = SiteSetting.default_locale
      target_locales =
        DiscourseAi::Translation.locales.reject do |locale|
          LocaleNormalizer.is_same?(locale, source_locale)
        end
      return if target_locales.empty?

      SiteSettingLocalization
        .where(setting_name: localizable_setting_names)
        .find_each do |localization|
          localization.destroy! if LocaleNormalizer.is_same?(localization.locale, source_locale)
        end

      remaining_limit = limit
      localizable_setting_names.each do |setting_name|
        break if remaining_limit <= 0

        next if SiteSetting.public_send(setting_name).blank?

        existing_locales = SiteSettingLocalization.where(setting_name:).pluck(:locale)
        missing_locales =
          target_locales.reject do |locale|
            existing_locales.any? do |existing_locale|
              LocaleNormalizer.is_same?(existing_locale, locale)
            end
          end

        missing_locales.each do |locale|
          break if remaining_limit <= 0

          begin
            DiscourseAi::Translation::SiteSettingLocalizer.localize(
              setting_name,
              locale,
              short_text_llm_model:,
              post_raw_llm_model:,
            )
          rescue FinalDestination::SSRFDetector::LookupFailedError
            # do nothing, there are too many sporadic lookup failures
          rescue => e
            DiscourseAi::Translation::VerboseLogger.log(
              "Failed to translate site setting #{setting_name} to #{locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
            )
          ensure
            remaining_limit -= 1
          end
        end
      end
    end

    private

    def localizable_setting_names
      @localizable_setting_names ||=
        SiteSettingLocalization.localizable_setting_names.select do |setting_name|
          SiteSettingLocalization.localizable?(setting_name)
        end
    end
  end
end
