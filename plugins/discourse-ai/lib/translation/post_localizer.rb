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
        localization.cooked = PrettyText.cook(translated_raw)
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
        Discourse.redis.get(relocalize_key(post, locale)) || 0
      end

      def self.incr_relocalize_quota(post, locale)
        key = relocalize_key(post, locale)

        if get_relocalize_quota(post, locale).blank?
          Discourse.redis.set(key, 1, ex: 1.day.to_i)
        else
          Discourse.redis.incr(key)
        end
      end
    end
  end
end
