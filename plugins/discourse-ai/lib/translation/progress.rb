# frozen_string_literal: true

module DiscourseAi
  module Translation
    class Progress
      CACHE_VERSION = 1
      CACHE_TTL = 2.hours
      DETAIL_CACHE_VERSION = 1
      DETAIL_CACHE_TTL = 2.hours
      TARGET_CLASSES = {
        "post" => PostCandidates,
        "topic" => TopicCandidates,
        "category" => CategoryCandidates,
        "tag" => TagCandidates,
      }.freeze
      TARGETS = TARGET_CLASSES.values.freeze

      def self.fetch
        Discourse
          .cache
          .fetch(cache_key, expires_in: CACHE_TTL) do
            { cached_at: Time.now.utc.iso8601, targets: TARGETS.map(&:progress_summary) }
          end
      end

      def self.fetch_detail(target_type)
        candidate_class = TARGET_CLASSES.fetch(target_type) { raise ArgumentError, target_type }
        cache_key = detail_cache_key(target_type)

        cached = Discourse.cache.read(cache_key)
        return cached if cached

        DistributedMutex.synchronize(detail_mutex_key(cache_key), validity: 5.minutes) do
          Discourse
            .cache
            .fetch(cache_key, expires_in: DETAIL_CACHE_TTL) do
              candidate_class.progress_details.merge(cached_at: Time.now.utc.iso8601)
            end
        end
      end

      def self.supported_target?(target_type)
        TARGET_CLASSES.key?(target_type)
      end

      def self.cache_key
        [
          "discourse-ai",
          "translation-progress-overview",
          "v#{CACHE_VERSION}",
          *settings_cache_key_parts,
        ].join(":")
      end

      def self.detail_cache_key(target_type)
        [
          "discourse-ai",
          "translation-progress-detail",
          "v#{DETAIL_CACHE_VERSION}",
          target_type,
          *settings_cache_key_parts,
        ].join(":")
      end

      def self.settings_cache_key_parts
        [
          SiteSetting.content_localization_supported_locales,
          SiteSetting.ai_translation_backfill_max_age_days,
          SiteSetting.ai_translation_include_bot_content,
          SiteSetting.ai_translation_max_post_length,
          SiteSetting.ai_translation_personal_messages,
          DiscourseAi::Translation.category_scope_cache_key,
        ]
      end

      def self.detail_mutex_key(cache_key)
        "discourse_ai_translation_progress_detail_#{Digest::SHA1.hexdigest(cache_key)}"
      end

      private_class_method :cache_key,
                           :detail_cache_key,
                           :settings_cache_key_parts,
                           :detail_mutex_key
    end
  end
end
