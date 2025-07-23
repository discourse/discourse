# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostLocalizer
      def self.localize(post, target_locale = I18n.locale)
        if post.blank? || target_locale.blank? || post.locale == target_locale.to_s ||
             post.raw.blank?
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
    end
  end
end
