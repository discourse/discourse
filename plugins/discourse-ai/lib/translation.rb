# frozen_string_literal: true

module DiscourseAi
  module Translation
    def self.enabled?
      SiteSetting.discourse_ai_enabled && SiteSetting.ai_translation_enabled &&
        SiteSetting.ai_translation_model.present? &&
        SiteSetting.content_localization_supported_locales.present?
    end

    def self.backfill_enabled?
      enabled? && SiteSetting.ai_translation_backfill_hourly_rate > 0 &&
        SiteSetting.ai_translation_backfill_max_age_days > 0
    end
  end
end
