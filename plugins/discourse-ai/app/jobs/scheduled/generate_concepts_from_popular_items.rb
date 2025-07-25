# frozen_string_literal: true

module Jobs
  class GenerateConceptsFromPopularItems < ::Jobs::Scheduled
    every 1.day

    # This job runs daily and generates new concepts from popular topics and posts
    # It selects items based on engagement metrics and generates concepts from their content
    def execute(_args)
      return unless SiteSetting.inferred_concepts_enabled

      process_popular_topics
      process_popular_posts
    end

    private

    def process_popular_topics
      # Find candidate topics that are popular and don't have concepts yet
      manager = DiscourseAi::InferredConcepts::Manager.new
      candidates =
        manager.find_candidate_topics(
          limit: SiteSetting.inferred_concepts_daily_topics_limit || 20,
          min_posts: SiteSetting.inferred_concepts_min_posts || 5,
          min_likes: SiteSetting.inferred_concepts_min_likes || 10,
          min_views: SiteSetting.inferred_concepts_min_views || 100,
          created_after: SiteSetting.inferred_concepts_lookback_days.days.ago,
        )

      return if candidates.blank?

      # Process candidate topics - first generate concepts, then match
      Jobs.enqueue(
        :generate_inferred_concepts,
        item_type: "topics",
        item_ids: candidates.map(&:id),
        batch_size: 10,
      )

      if SiteSetting.inferred_concepts_background_match
        # Schedule a follow-up job to match existing concepts
        Jobs.enqueue_in(
          1.hour,
          :generate_inferred_concepts,
          item_type: "topics",
          item_ids: candidates.map(&:id),
          batch_size: 10,
          match_only: true,
        )
      end
    end

    def process_popular_posts
      # Find candidate posts that are popular and don't have concepts yet
      manager = DiscourseAi::InferredConcepts::Manager.new
      candidates =
        manager.find_candidate_posts(
          limit: SiteSetting.inferred_concepts_daily_posts_limit || 30,
          min_likes: SiteSetting.inferred_concepts_post_min_likes || 5,
          exclude_first_posts: true,
          created_after: SiteSetting.inferred_concepts_lookback_days.days.ago,
        )

      return if candidates.blank?

      # Process candidate posts - first generate concepts, then match
      Jobs.enqueue(
        :generate_inferred_concepts,
        item_type: "posts",
        item_ids: candidates.map(&:id),
        batch_size: 10,
      )

      if SiteSetting.inferred_concepts_background_match
        # Schedule a follow-up job to match against existing concepts
        Jobs.enqueue_in(
          1.hour,
          :generate_inferred_concepts,
          item_type: "posts",
          item_ids: candidates.map(&:id),
          batch_size: 10,
          match_only: true,
        )
      end
    end
  end
end
