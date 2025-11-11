# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TopicLocalizer
      def self.localize(topic, target_locale = I18n.locale)
        return if topic.blank? || target_locale.blank? || topic.locale == target_locale.to_s

        target_locale = target_locale.to_s.sub("-", "_")

        translated_title =
          TopicTitleTranslator.new(text: topic.title, target_locale:, topic:).translate
        translated_excerpt =
          PostRawTranslator.new(text: topic.excerpt, target_locale:, topic:).translate

        localization =
          TopicLocalization.find_or_initialize_by(topic_id: topic.id, locale: target_locale)

        localization.title = translated_title
        localization.fancy_title = Topic.fancy_title(translated_title)
        localization.excerpt = translated_excerpt
        localization.localizer_user_id = Discourse.system_user.id
        localization.save!
        localization
      end
    end
  end
end
