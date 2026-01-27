# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class RegenerateSummaries
      include Service::Base

      MAX_TOPICS = TopicQuery::DEFAULT_PER_PAGE_COUNT
      TYPES = %i[gist summary].freeze

      params do
        attribute :topic_id, :integer
        attribute :topic_ids, :array
        attribute :type, :string, default: "summary"

        before_validation do
          if topic_ids.present?
            self.topic_ids = Array(topic_ids).map(&:to_i).uniq
          elsif topic_id.present?
            self.topic_ids = [topic_id.to_i]
          end
          self.type = type.to_s
        end

        validates :topic_ids, presence: true
        validates :type, inclusion: { in: TYPES.map(&:to_s) }
        validate :topic_ids_within_limit

        def topic_ids_within_limit
          return if topic_ids.blank?
          if topic_ids.size > MAX_TOPICS
            errors.add(:topic_ids, "cannot exceed #{MAX_TOPICS} topics")
          end
        end
      end

      policy :can_regenerate

      step :rate_limit
      step :fetch_topics
      step :regenerate

      private

      def can_regenerate(guardian:, params:)
        if params.type == "gist"
          guardian.can_request_gists?
        else
          guardian.can_regenerate_summary?
        end
      end

      def rate_limit(guardian:, params:)
        if guardian.user && params.topic_ids.size >= 1
          RateLimiter.new(guardian.user, "summary", 6, 5.minutes).performed!
        end
        true
      end

      def fetch_topics(params:, guardian:)
        topics = Topic.where(id: params.topic_ids)

        topics.each { |topic| guardian.ensure_can_see!(topic) }

        context[:topics] = topics
      end

      def regenerate(topics:, params:, guardian:)
        topics.each do |topic|
          if params.type == "gist"
            summarizer = DiscourseAi::Summarization.topic_gist(topic)
            summarizer.delete_cached_summaries! if summarizer.present?

            Jobs.enqueue(:fast_track_topic_gist, topic_id: topic.id, force_regenerate: true)
          else
            summarizer = DiscourseAi::Summarization.topic_summary(topic)
            summarizer.delete_cached_summaries! if summarizer.present?

            Jobs.enqueue(
              :stream_topic_ai_summary,
              topic_id: topic.id,
              user_id: guardian.user.id,
              skip_age_check: true,
            )
          end
        end
      end
    end
  end
end
