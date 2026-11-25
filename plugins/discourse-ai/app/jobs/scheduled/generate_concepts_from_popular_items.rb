# frozen_string_literal: true

module Jobs
  class GenerateConceptsFromPopularItems < ::Jobs::Scheduled
    every 1.day

    # This job runs daily and generates new concepts from popular topics and posts
    # It selects items based on engagement metrics and generates concepts from their content
    def execute(_args)
      return unless SiteSetting.inferred_concepts_enabled && DiscourseAi::Embeddings.enabled?

      process_popular_topics
      process_popular_posts
    end

    private

    def process_popular_topics
      limit = SiteSetting.inferred_concepts_daily_topics_limit.to_i
      return if limit <= 0

      # Find candidate topics that are popular and don't have concepts yet
      manager = DiscourseAi::InferredConcepts::Manager.new
      candidates =
        manager.find_candidate_topics(
          limit: limit,
          min_posts: SiteSetting.inferred_concepts_min_posts || 5,
          min_likes: SiteSetting.inferred_concepts_min_likes || 10,
          min_views: SiteSetting.inferred_concepts_min_views || 100,
          created_after: SiteSetting.inferred_concepts_lookback_days.days.ago,
        )

      return if candidates.blank?

      # Process candidate topics in a single classify + stage pass
      Jobs.enqueue(
        :generate_inferred_concepts,
        item_type: "topics",
        item_ids: candidates.map(&:id),
        batch_size: 10,
      )
    end

    def process_popular_posts
      limit = SiteSetting.inferred_concepts_daily_posts_limit.to_i
      return if limit <= 0

      # Find candidate posts that are popular and don't have concepts yet
      manager = DiscourseAi::InferredConcepts::Manager.new
      candidates =
        manager.find_candidate_posts(
          limit: limit,
          min_likes: SiteSetting.inferred_concepts_post_min_likes || 5,
          exclude_first_posts: true,
          created_after: SiteSetting.inferred_concepts_lookback_days.days.ago,
        )

      return if candidates.blank?

      # Process candidate posts in a single classify + stage pass
      Jobs.enqueue(
        :generate_inferred_concepts,
        item_type: "posts",
        item_ids: candidates.map(&:id),
        batch_size: 10,
      )
    end
  end
end
