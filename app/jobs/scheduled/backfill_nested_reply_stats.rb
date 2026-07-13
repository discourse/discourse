# frozen_string_literal: true

module Jobs
  class BackfillNestedReplyStats < ::Jobs::Scheduled
    every 5.minutes

    cluster_concurrency 1

    # The next scheduled run resumes any remaining backlog.
    MAX_DRAIN_BATCHES = 20

    def execute(args = {})
      return unless SiteSetting.nested_replies_enabled

      args ||= {}
      if args[:topic_id].present?
        backfill_topic(args[:topic_id])
        return
      end

      topic_ids =
        topic_ids_missing_stats(
          category_id: args[:category_id],
          after_topic_id: args[:after_topic_id],
        )
      failed = false
      topic_ids.each do |topic_id|
        NestedReplies::StructuralStats.recalculate_topic(topic_id)
      rescue => error
        failed = true
        Discourse.warn_exception(
          error,
          message: "Failed to backfill nested reply stats for topic #{topic_id}",
        )
      end

      unless failed
        enqueue_continuation(
          topic_ids,
          category_id: args[:category_id],
          drain_batch: [args[:drain_batch].to_i, 1].max,
        )
      end
    end

    private

    def backfill_topic(topic_id)
      return unless eligible_topic?(topic_id)

      NestedReplies::StructuralStats.recalculate_topic(topic_id)
    end

    def eligible_topic?(topic_id)
      DB.query_single(
        <<~SQL,
          SELECT 1
          FROM topics
          LEFT JOIN nested_topics ON nested_topics.topic_id = topics.id
          INNER JOIN posts original_post
            ON original_post.topic_id = topics.id
           AND original_post.post_number = 1
          WHERE topics.id = :topic_id
            AND topics.deleted_at IS NULL
            AND topics.archetype = :archetype
            AND (:nested_replies_default OR nested_topics.topic_id IS NOT NULL)
          LIMIT 1
        SQL
        topic_id: topic_id,
        archetype: Archetype.default,
        nested_replies_default: SiteSetting.nested_replies_default,
      ).present?
    end

    def topic_ids_missing_stats(category_id: nil, after_topic_id: nil)
      category_id = category_id.to_i
      after_topic_id = after_topic_id.to_i
      category_filter = category_id.positive? ? "AND topics.category_id = :category_id" : ""

      DB.query_single(
        <<~SQL,
          SELECT topics.id
          FROM topics
          LEFT JOIN nested_topics ON nested_topics.topic_id = topics.id
          INNER JOIN posts original_post
            ON original_post.topic_id = topics.id
           AND original_post.post_number = 1
          LEFT JOIN nested_view_post_stats stats ON stats.post_id = original_post.id
          WHERE topics.deleted_at IS NULL
            AND topics.archetype = :archetype
            AND (:nested_replies_default OR nested_topics.topic_id IS NOT NULL)
            AND topics.id > :after_topic_id
            #{category_filter}
            AND EXISTS (
              SELECT 1
              FROM posts replies
              WHERE replies.topic_id = topics.id
                AND replies.post_number > 1
            )
            AND stats.structural_backfilled_at IS NULL
          ORDER BY topics.id
          LIMIT :batch_size
        SQL
        archetype: Archetype.default,
        batch_size: SiteSetting.nested_replies_backfill_batch_size,
        category_id: category_id,
        after_topic_id: after_topic_id,
        nested_replies_default: SiteSetting.nested_replies_default,
      )
    end

    def enqueue_continuation(topic_ids, category_id: nil, drain_batch:)
      return if topic_ids.size < SiteSetting.nested_replies_backfill_batch_size
      return if drain_batch >= MAX_DRAIN_BATCHES

      args = { after_topic_id: topic_ids.last, drain_batch: drain_batch + 1 }
      args[:category_id] = category_id if category_id.to_i.positive?
      Jobs.enqueue(:backfill_nested_reply_stats, args)
    end
  end
end
