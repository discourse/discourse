# frozen_string_literal: true

module Jobs
  class PrepareNestedReplyStats < ::Jobs::Base
    sidekiq_options queue: "low"
    cluster_concurrency 1

    def execute(args = {})
      raise Discourse::ReadOnly if Discourse.readonly_mode?

      args ||= {}
      isolated_topic_id = args[:topic_id].to_i
      if isolated_topic_id.positive?
        Jobs::BackfillNestedReplyStats.backfill_topic(isolated_topic_id)
        return
      end

      after_topic_id = args[:after_topic_id].to_i
      max_topic_id = args[:max_topic_id].to_i
      max_topic_id = maximum_topic_id if max_topic_id.zero?

      if after_topic_id >= max_topic_id
        log_completion(max_topic_id)
        return
      end

      topic_ids = topic_ids_to_prepare(after_topic_id:, max_topic_id:)
      if topic_ids.empty?
        log_completion(max_topic_id)
        return
      end

      topic_ids.each do |topic_id|
        Jobs::BackfillNestedReplyStats.backfill_topic(topic_id)
      rescue => error
        Discourse.warn_exception(
          error,
          message: "Failed to prepare nested reply stats for topic #{topic_id}",
        )
        Jobs.enqueue(:prepare_nested_reply_stats, topic_id: topic_id)
      end
      after_topic_id = topic_ids.last

      if after_topic_id < max_topic_id
        Jobs.enqueue(:prepare_nested_reply_stats, after_topic_id:, max_topic_id:)
      else
        log_completion(max_topic_id)
      end
    end

    private

    def maximum_topic_id
      Topic.where(archetype: Archetype.default, deleted_at: nil).maximum(:id).to_i
    end

    def topic_ids_to_prepare(after_topic_id:, max_topic_id:)
      DB.query_single(
        <<~SQL,
          SELECT topics.id
          FROM topics
          INNER JOIN posts op
            ON op.topic_id = topics.id
           AND op.post_number = 1
          WHERE topics.id > :after_topic_id
            AND topics.id <= :max_topic_id
            AND topics.deleted_at IS NULL
            AND topics.archetype = :archetype
          ORDER BY topics.id
          LIMIT :batch_size
        SQL
        after_topic_id: after_topic_id,
        max_topic_id: max_topic_id,
        archetype: Archetype.default,
        batch_size: SiteSetting.nested_replies_backfill_batch_size,
      )
    end

    def log_completion(max_topic_id)
      Rails.logger.info("Nested reply stats preparation completed through topic #{max_topic_id}")
    end
  end
end
