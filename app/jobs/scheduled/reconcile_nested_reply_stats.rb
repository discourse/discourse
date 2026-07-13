# frozen_string_literal: true

module Jobs
  class ReconcileNestedReplyStats < ::Jobs::Scheduled
    every 1.hour

    cluster_concurrency 1

    def execute(_args = {})
      return unless SiteSetting.nested_replies_enabled

      topic_ids.each { |topic_id| NestedReplies::StructuralStats.recalculate_topic(topic_id) }
    end

    private

    def topic_ids
      # Initial backfill selection stays cheap by looking only for a missing
      # marker. This rotating pass is where already-marked topics are repaired.
      DB.query_single(
        <<~SQL,
          SELECT topics.id
          FROM topics
          LEFT JOIN nested_topics ON nested_topics.topic_id = topics.id
          INNER JOIN posts original_post
            ON original_post.topic_id = topics.id
           AND original_post.post_number = 1
          INNER JOIN nested_view_post_stats stats ON stats.post_id = original_post.id
          WHERE topics.deleted_at IS NULL
            AND topics.archetype = :archetype
            AND (:nested_replies_default OR nested_topics.topic_id IS NOT NULL)
            AND stats.structural_backfilled_at IS NOT NULL
            AND EXISTS (
              SELECT 1
              FROM posts replies
              WHERE replies.topic_id = topics.id
                AND replies.post_number > 1
            )
          ORDER BY stats.structural_backfilled_at, topics.id
          LIMIT :batch_size
        SQL
        archetype: Archetype.default,
        batch_size: SiteSetting.nested_replies_reconciliation_batch_size,
        nested_replies_default: SiteSetting.nested_replies_default,
      )
    end
  end
end
