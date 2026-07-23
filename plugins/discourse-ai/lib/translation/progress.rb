# frozen_string_literal: true

module DiscourseAi
  module Translation
    class Progress
      CACHE_VERSION = 1
      CACHE_TTL = 2.hours
      TARGETS = [PostCandidates, TopicCandidates, CategoryCandidates, TagCandidates].freeze

      def self.fetch
        Discourse
          .cache
          .fetch(cache_key, expires_in: CACHE_TTL) do
            { cached_at: Time.now.utc.iso8601, targets: TARGETS.map(&:progress_summary) }
          end
      end

      def self.cache_key
        [
          "discourse-ai",
          "translation-progress-overview",
          "v#{CACHE_VERSION}",
          SiteSetting.content_localization_supported_locales,
          SiteSetting.ai_translation_backfill_max_age_days,
          SiteSetting.ai_translation_include_bot_content,
          SiteSetting.ai_translation_max_post_length,
          SiteSetting.ai_translation_personal_messages,
          DiscourseAi::Translation.category_scope_cache_key,
        ].join(":")
      end
      private_class_method :cache_key
    end
  end
end
