# frozen_string_literal: true

module Jobs
  class ProcessNestedReplyUpdates < ::Jobs::Scheduled
    every 1.minute

    cluster_concurrency 1

    BATCH_SIZE = 100
    MAX_DRAIN_BATCHES = 20

    def execute(_args = {})
      return unless SiteSetting.nested_replies_enabled

      should_finish = true
      NestedReplies::RecalculationQueue.recover_hot_posts
      MAX_DRAIN_BATCHES.times do
        batch = NestedReplies::RecalculationQueue.pop_batch(BATCH_SIZE)
        break if batch.values.all?(&:empty?)

        process_structural_topics(batch[:structural_topic_ids])
        process_hot_topics(batch[:hot_topic_ids])
        process_hot_posts(batch[:hot_post_ids], batch[:hot_topic_ids])
        NestedReplies::RecalculationQueue.acknowledge_hot_posts(batch[:hot_post_ids])
      end
    ensure
      if should_finish && NestedReplies::RecalculationQueue.finish
        NestedReplies::RecalculationQueue.enqueue_continuation
      end
    end

    private

    def process_structural_topics(topic_ids)
      eligible_topic_ids(topic_ids).each do |topic_id|
        NestedReplies::StructuralStats.recalculate_topic(topic_id)
      rescue => error
        Discourse.warn_exception(
          error,
          message: "Failed to recalculate nested reply stats for topic #{topic_id}",
        )
      end
    end

    def process_hot_topics(topic_ids)
      eligible_topic_ids(topic_ids).each do |topic_id|
        NestedReplies::HotScoreCalculator.recalculate_topic(topic_id)
      rescue => error
        Discourse.warn_exception(
          error,
          message: "Failed to recalculate nested hot scores for topic #{topic_id}",
        )
      end
    end

    def process_hot_posts(post_ids, rebuilt_topic_ids)
      posts =
        Post
          .with_deleted
          .where(id: post_ids)
          .where.not(post_number: 1)
          .select(:id, :topic_id)
          .group_by(&:topic_id)
      current_topic_ids = hot_scores_current_topic_ids(posts.keys)
      eligible_ids = eligible_topic_ids(posts.keys)

      posts.each do |topic_id, topic_posts|
        next if eligible_ids.exclude?(topic_id)
        next if rebuilt_topic_ids.include?(topic_id)

        if current_topic_ids.include?(topic_id)
          NestedReplies::HotScoreCalculator.recalculate_posts_for_topic(
            topic_id,
            topic_posts.map(&:id),
          )
        else
          NestedReplies::HotScoreCalculator.recalculate_topic(topic_id)
        end
      rescue => error
        NestedReplies::RecalculationQueue.invalidate_completion_markers(
          [topic_id],
          structural: false,
          hot: true,
        )
        Discourse.warn_exception(
          error,
          message: "Failed to update nested hot scores for topic #{topic_id}",
        )
      end
    end

    def hot_scores_current_topic_ids(topic_ids)
      return [] if topic_ids.empty?

      NestedViewPostStat
        .joins(:post)
        .where(posts: { topic_id: topic_ids, post_number: 1 })
        .where("hot_score_updated_at >= ?", Time.zone.at(NestedReplies::StatsFreshness.valid_after))
        .pluck("posts.topic_id")
    end

    def eligible_topic_ids(topic_ids)
      NestedReplies::RecalculationQueue.eligible_topic_ids(topic_ids)
    end
  end
end
