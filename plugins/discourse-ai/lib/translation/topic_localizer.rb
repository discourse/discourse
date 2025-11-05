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

      # Checks if a topic has remaining quota for re-localization attempts.
      # Uses atomic Redis INCR to prevent race conditions.
      # The quota key expires after 24 hours, allowing retries after that period.
      #
      # @param topic_id [Integer] The topic ID
      # @param locale [String] The target locale
      # @return [Boolean] true if quota is available (attempts <= 2), false if exhausted
      def self.has_relocalize_quota?(topic_id, locale)
        key = relocalize_key(topic_id, locale)
        count = Discourse.redis.incr(key)
        # Only set expiry on first increment to avoid resetting the TTL on subsequent checks
        Discourse.redis.expire(key, 1.day.to_i) if count == 1
        count <= 2
      end

      private

      def self.relocalize_key(topic_id, locale)
        "topic_relocalized_#{topic_id}_#{locale}"
      end
    end
  end
end
