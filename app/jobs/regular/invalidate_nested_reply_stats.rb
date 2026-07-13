# frozen_string_literal: true

module Jobs
  class InvalidateNestedReplyStats < ::Jobs::Base
    BATCH_SIZE = 1000

    def execute(args = {})
      return unless SiteSetting.nested_replies_enabled

      topic_ids = eligible_topic_ids(after_topic_id: args[:after_topic_id].to_i)
      return if topic_ids.empty?

      NestedReplies::RecalculationQueue.enqueue_topic_rebuilds(
        topic_ids,
        structural: true,
        hot: true,
      )

      if topic_ids.size == BATCH_SIZE
        Jobs.enqueue(:invalidate_nested_reply_stats, after_topic_id: topic_ids.last)
      end
    end

    private

    def eligible_topic_ids(after_topic_id:)
      DB.query_single(
        <<~SQL,
          SELECT topics.id
          FROM topics
          LEFT JOIN nested_topics ON nested_topics.topic_id = topics.id
          WHERE topics.id > :after_topic_id
            AND topics.deleted_at IS NULL
            AND topics.archetype = :archetype
            AND (:nested_by_default OR nested_topics.topic_id IS NOT NULL)
          ORDER BY topics.id
          LIMIT :batch_size
        SQL
        after_topic_id: after_topic_id,
        archetype: Archetype.default,
        batch_size: BATCH_SIZE,
        nested_by_default: SiteSetting.nested_replies_default,
      )
    end
  end
end
