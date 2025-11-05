# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostLocalizer
      def self.localize(post, target_locale = I18n.locale)
        if post.blank? || target_locale.blank? ||
             LocaleNormalizer.is_same?(post.locale, target_locale) || post.raw.blank?
          return
        end
        return if post.raw.length > SiteSetting.ai_translation_max_post_length
        target_locale = target_locale.to_s.sub("-", "_")

        translated_raw = PostRawTranslator.new(text: post.raw, target_locale:, post:).translate

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

      # Checks if a post has remaining quota for re-localization attempts.
      # Uses atomic Redis INCR to prevent race conditions.
      # The quota key expires after 24 hours, allowing retries after that period.
      #
      # @param post_id [Integer] The post ID
      # @param locale [String] The target locale
      # @return [Boolean] true if quota is available (attempts <= 2), false if exhausted
      def self.has_relocalize_quota?(post_id, locale)
        key = relocalize_key(post_id, locale)
        count = Discourse.redis.incr(key)
        # Only set expiry on first increment to avoid resetting the TTL on subsequent checks
        Discourse.redis.expire(key, 1.day.to_i) if count == 1
        count <= 2
      end

      private

      def self.relocalize_key(post_id, locale)
        "post_relocalized_#{post_id}_#{locale}"
      end
    end
  end
end
