# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostLocalizer
      include LocalizableQuota

      def self.localize(post, target_locale = I18n.locale, llm_model: nil)
        if post.blank? || target_locale.blank? ||
             LocaleNormalizer.is_same?(post.locale, target_locale) || post.raw.blank?
          return
        end
        return if post.raw.length > SiteSetting.ai_translation_max_post_length
        target_locale = target_locale.to_s.sub("-", "_")

        translated_raw =
          PostRawTranslator.new(text: post.raw, target_locale:, post:, llm_model:).translate

        localization =
          PostLocalization.find_or_initialize_by(post_id: post.id, locale: target_locale)

        localization.raw = translated_raw
        localization.cooked = post.post_analyzer.cook(translated_raw, post.cooking_options || {})

        cooked_processor = LocalizedCookedPostProcessor.new(localization, post, {})
        begin
          cooked_processor.post_process
          localization.cooked = cooked_processor.html
        rescue => e
          # Log but don't fail translation if post-processing (oneboxes, images) fails
          Rails.logger.warn(
            "Post-processing failed for localization of post #{post.id} to #{target_locale}: #{e.class} - #{e.message}",
          )
          # Keep the cooked content without post-processing
        end

        localization.post_version = post.version
        localization.localizer_user_id = Discourse.system_user.id
        localization.save!
        localization
      end

      def self.model_name
        "post"
      end
    end
  end
end
