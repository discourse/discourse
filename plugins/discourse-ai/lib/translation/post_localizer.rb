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

      def self.has_relocalize_quota?(post, locale, skip_incr: false)
        return false if get_relocalize_quota(post, locale).to_i >= 2

        incr_relocalize_quota(post, locale) unless skip_incr
        true
      end

      private

      def self.relocalize_key(post, locale)
        "post_relocalized_#{post.id}_#{locale}"
      end

      def self.get_relocalize_quota(post, locale)
        Discourse.redis.get(relocalize_key(post, locale)).to_i || 0
      end

      def self.incr_relocalize_quota(post, locale)
        key = relocalize_key(post, locale)

        if (count = get_relocalize_quota(post, locale)).zero?
          Discourse.redis.set(key, 1, ex: 1.day.to_i)
        else
          ttl = Discourse.redis.ttl(key)
          incr = count.to_i + 1
          Discourse.redis.set(key, incr, ex: ttl)
        end
      end
    end
  end
end
