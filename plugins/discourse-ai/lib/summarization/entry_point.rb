# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class EntryPoint
      def inject_into(plugin)
        plugin.add_to_serializer(:current_user, :can_request_gists) { scope.can_request_gists? }

        plugin.add_to_serializer(:current_user, :can_summarize) do
          return false if !SiteSetting.ai_summarization_enabled

          if (ai_agent = AiAgent.find_by_id_from_cache(SiteSetting.ai_summarization_agent)).blank?
            return false
          end
          scope.user.in_any_groups?(ai_agent.allowed_group_ids.to_a)
        end

        plugin.add_to_serializer(:topic_view, :summarizable) do
          scope.can_see_summary?(object.topic, cached_summary: ai_summary_record)
        end

        plugin.add_to_serializer(:topic_view, :has_cached_summary) { ai_summary_record.present? }

        plugin.add_to_serializer(:web_hook_topic_view, :summarizable) do
          cached_summary =
            DiscourseAi::TopicSummarization.for(object.topic, scope.user, scope:).cached_summary
          scope.can_see_summary?(object.topic, cached_summary: cached_summary)
        end

        plugin.add_to_serializer(
          :topic_view,
          :ai_summary_record,
          include_condition: -> { false },
        ) do
          return @ai_summary_record if defined?(@ai_summary_record)
          @ai_summary_record =
            DiscourseAi::TopicSummarization.for(object.topic, scope.user, scope:).cached_summary
        end

        plugin.add_to_serializer(
          :topic_view,
          :ai_summary,
          include_condition: -> do
            next false if !DiscoursePluginRegistry.apply_modifier(:serialize_ai_summary, false)

            summary_record = ai_summary_record
            scope.can_see_summary?(object.topic, cached_summary: summary_record) &&
              summary_record.present?
          end,
        ) do
          {
            id: ai_summary_record.id,
            summarized_text: ai_summary_record.summarized_text,
            algorithm: ai_summary_record.algorithm,
            outdated: ai_summary_record.outdated,
            created_at: ai_summary_record.created_at,
            updated_at: ai_summary_record.updated_at,
          }
        end

        plugin.register_modifier(:topic_query_create_list_topics) do |topics, options|
          unless SiteSetting.ai_summarization_enabled && SiteSetting.ai_summary_gists_enabled
            next topics
          end

          if topics.respond_to?(:includes)
            # For ActiveRecord relations, use includes to preload gists
            topics.includes(:ai_gist_summaries)
          elsif topics.is_a?(Array) && topics.present?
            # For Arrays (like suggested topics), preload associations manually
            ActiveRecord::Associations::Preloader.new(
              records: topics,
              associations: :ai_gist_summaries,
            ).call
            topics
          else
            topics
          end
        end

        plugin.add_to_serializer(
          :topic_list_item,
          :ai_topic_gist,
          include_condition: -> { scope.can_see_gists? },
        ) { DiscourseAi::Summarization.gist_for(object, scope:)&.summarized_text }

        plugin.add_to_serializer(
          :suggested_topic,
          :ai_topic_gist,
          include_condition: -> { scope.can_see_gists? },
        ) { DiscourseAi::Summarization.gist_for(object, scope:)&.summarized_text }

        # As this event can be triggered quite often, let's be overly cautious enqueueing
        # jobs if the feature is disabled.
        plugin.on(:post_created) do |post|
          if SiteSetting.discourse_ai_enabled && SiteSetting.ai_summarization_enabled &&
               SiteSetting.ai_summary_gists_enabled && post.topic
            enqueue_gist_jobs(post.topic, minimum_target_number: post.post_number)
          end
        end

        plugin.on(:posts_moved) do |args|
          if SiteSetting.discourse_ai_enabled && SiteSetting.ai_summarization_enabled &&
               !SiteSetting.ai_summary_backfill_maximum_topics_per_hour.zero?
            topic_ids = [args[:original_topic_id], args[:destination_topic_id]].compact.uniq

            # Mark existing summaries for regeneration by resetting highest_target_number
            AiSummary.where(target_type: "Topic", target_id: topic_ids).update_all(
              highest_target_number: 0,
            )

            # Fast-track gist regeneration since they appear in topic lists
            if SiteSetting.ai_summary_gists_enabled
              Topic
                .where(id: topic_ids)
                .find_each { |topic| enqueue_gist_jobs(topic, force_regenerate: true) }
            end
          end
        end
      end

      private

      def enqueue_gist_jobs(topic, force_regenerate: false, minimum_target_number: nil)
        locales = DiscourseAi::Summarization.gist_locales(topic)
        return if locales.empty?

        target_number = [topic.highest_post_number, minimum_target_number].compact.max
        existing_gists =
          AiSummary.gist.where(target: topic).select(:locale, :created_at, :highest_target_number)

        locales.each do |locale|
          existing_gist =
            existing_gists.find do |gist|
              gist.locale == locale ||
                (
                  gist.locale.present? && locale.present? &&
                    LocaleNormalizer.is_same?(gist.locale, locale)
                )
            end
          if existing_gist && !force_regenerate
            gist_is_current = existing_gist.highest_target_number >= target_number
            gist_is_recent = existing_gist.created_at >= 5.minutes.ago
            next if gist_is_current || gist_is_recent
          end

          Jobs.enqueue(:fast_track_topic_gist, topic_id: topic.id, locale:, force_regenerate:)
        end
      end
    end
  end
end
