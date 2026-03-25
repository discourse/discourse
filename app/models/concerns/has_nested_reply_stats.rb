# frozen_string_literal: true

module HasNestedReplyStats
  extend ActiveSupport::Concern

  included do
    attr_accessor :precomputed_reactions

    after_create :nested_replies_increment_stats
    after_destroy :nested_replies_decrement_stats
  end

  private

  def nested_replies_increment_stats
    return if reply_to_post_number.blank?

    ancestors =
      NestedReplies.walk_ancestors(
        topic_id: topic_id,
        start_post_number: reply_to_post_number,
        exclude_deleted: true,
      )

    return if ancestors.empty?

    ancestor_ids = ancestors.map(&:id)
    direct_parent_id = ancestors.find { |a| a.depth == 1 }&.id
    is_whisper = post_type == Post.types[:whisper] ? 1 : 0

    DB.exec(<<~SQL, ids: ancestor_ids, parent_id: direct_parent_id, whisper: is_whisper)
      INSERT INTO nested_view_post_stats (post_id, direct_reply_count, total_descendant_count,
                                           whisper_direct_reply_count, whisper_total_descendant_count,
                                           created_at, updated_at)
      SELECT aid,
             CASE WHEN aid = :parent_id THEN 1 ELSE 0 END,
             1,
             CASE WHEN aid = :parent_id THEN :whisper ELSE 0 END,
             :whisper,
             NOW(), NOW()
      FROM unnest(ARRAY[:ids]::int[]) AS aid
      ON CONFLICT (post_id) DO UPDATE SET
        total_descendant_count = nested_view_post_stats.total_descendant_count + 1,
        direct_reply_count = nested_view_post_stats.direct_reply_count +
          CASE WHEN nested_view_post_stats.post_id = :parent_id THEN 1 ELSE 0 END,
        whisper_total_descendant_count = nested_view_post_stats.whisper_total_descendant_count + :whisper,
        whisper_direct_reply_count = nested_view_post_stats.whisper_direct_reply_count +
          CASE WHEN nested_view_post_stats.post_id = :parent_id THEN :whisper ELSE 0 END,
        updated_at = NOW()
    SQL
  end

  def nested_replies_decrement_stats
    if reply_to_post_number.present?
      stat =
        NestedViewPostStat.where(post_id: id).pick(
          :total_descendant_count,
          :whisper_total_descendant_count,
        )
      my_descendants = stat&.first || 0
      my_whisper_descendants = stat&.second || 0
      removed = 1 + my_descendants
      is_whisper = post_type == Post.types[:whisper] ? 1 : 0
      whisper_removed = is_whisper + my_whisper_descendants

      ancestors =
        NestedReplies.walk_ancestors(
          topic_id: topic_id,
          start_post_number: reply_to_post_number,
          exclude_deleted: false,
        )

      if ancestors.present?
        ancestor_ids = ancestors.map(&:id)
        direct_parent_id = ancestors.find { |a| a.depth == 1 }&.id

        DB.exec(
          <<~SQL,
          UPDATE nested_view_post_stats
          SET total_descendant_count = GREATEST(total_descendant_count - :removed, 0),
              direct_reply_count = GREATEST(
                direct_reply_count - CASE WHEN post_id = :parent_id THEN 1 ELSE 0 END,
                0
              ),
              whisper_total_descendant_count = GREATEST(whisper_total_descendant_count - :whisper_removed, 0),
              whisper_direct_reply_count = GREATEST(
                whisper_direct_reply_count - CASE WHEN post_id = :parent_id THEN :is_whisper ELSE 0 END,
                0
              ),
              updated_at = NOW()
          WHERE post_id = ANY(ARRAY[:ids]::int[])
        SQL
          ids: ancestor_ids,
          parent_id: direct_parent_id,
          removed: removed,
          whisper_removed: whisper_removed,
          is_whisper: is_whisper,
        )
      end
    end

    NestedViewPostStat.where(post_id: id).delete_all
  end
end
