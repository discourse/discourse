# frozen_string_literal: true

module HasNestedReplyStats
  extend ActiveSupport::Concern

  included do
    after_create :nested_replies_increment_stats
    after_destroy :nested_replies_decrement_stats
  end

  # Moves this post's subtree from `previous_reply_to_post_number` to its
  # current `reply_to_post_number` on the nested stats tree. Shared ancestors
  # are left alone — their total descendant count is unchanged — while
  # ancestors unique to either chain are adjusted by this post's subtree size.
  def nested_replies_apply_reparent(previous_reply_to_post_number)
    return unless SiteSetting.nested_replies_enabled
    return if previous_reply_to_post_number == reply_to_post_number

    subtree_size, whisper_subtree_size = nested_replies_subtree_sizes
    is_whisper = post_type == Post.types[:whisper] ? 1 : 0

    old_ancestors = nested_replies_walk(previous_reply_to_post_number)
    new_ancestors = nested_replies_walk(reply_to_post_number)

    old_ids = old_ancestors.map(&:id)
    new_ids = new_ancestors.map(&:id)
    old_only_ids = old_ids - new_ids
    new_only_ids = new_ids - old_ids

    old_direct_parent_id = old_ancestors.find { |a| a.depth == 1 }&.id
    new_direct_parent_id = new_ancestors.find { |a| a.depth == 1 }&.id

    if old_only_ids.any?
      DB.exec(<<~SQL, ids: old_only_ids, subtree: subtree_size, whisper: whisper_subtree_size)
        UPDATE nested_view_post_stats
        SET total_descendant_count = GREATEST(total_descendant_count - :subtree, 0),
            whisper_total_descendant_count = GREATEST(whisper_total_descendant_count - :whisper, 0),
            updated_at = NOW()
        WHERE post_id = ANY(ARRAY[:ids]::int[])
      SQL
    end

    if new_only_ids.any?
      DB.exec(<<~SQL, ids: new_only_ids, subtree: subtree_size, whisper: whisper_subtree_size)
        INSERT INTO nested_view_post_stats (post_id, direct_reply_count, total_descendant_count,
                                             whisper_direct_reply_count, whisper_total_descendant_count,
                                             created_at, updated_at)
        SELECT aid, 0, :subtree, 0, :whisper, NOW(), NOW()
        FROM unnest(ARRAY[:ids]::int[]) AS aid
        ON CONFLICT (post_id) DO UPDATE SET
          total_descendant_count = nested_view_post_stats.total_descendant_count + :subtree,
          whisper_total_descendant_count = nested_view_post_stats.whisper_total_descendant_count + :whisper,
          updated_at = NOW()
      SQL
    end

    DB.exec(<<~SQL, id: old_direct_parent_id, is_whisper: is_whisper) if old_direct_parent_id
        UPDATE nested_view_post_stats
        SET direct_reply_count = GREATEST(direct_reply_count - 1, 0),
            whisper_direct_reply_count = GREATEST(whisper_direct_reply_count - :is_whisper, 0),
            updated_at = NOW()
        WHERE post_id = :id
      SQL

    DB.exec(<<~SQL, id: new_direct_parent_id, is_whisper: is_whisper) if new_direct_parent_id
        INSERT INTO nested_view_post_stats (post_id, direct_reply_count, total_descendant_count,
                                             whisper_direct_reply_count, whisper_total_descendant_count,
                                             created_at, updated_at)
        VALUES (:id, 1, 0, :is_whisper, 0, NOW(), NOW())
        ON CONFLICT (post_id) DO UPDATE SET
          direct_reply_count = nested_view_post_stats.direct_reply_count + 1,
          whisper_direct_reply_count = nested_view_post_stats.whisper_direct_reply_count + :is_whisper,
          updated_at = NOW()
      SQL
  end

  private

  def nested_replies_increment_stats
    return unless SiteSetting.nested_replies_enabled
    return if reply_to_post_number.blank?

    ancestors = nested_replies_walk(reply_to_post_number)
    return if ancestors.empty?

    ancestor_ids = ancestors.map(&:id).uniq
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
    return unless SiteSetting.nested_replies_enabled
    if reply_to_post_number.present?
      subtree_size, whisper_subtree_size = nested_replies_subtree_sizes
      is_whisper = post_type == Post.types[:whisper] ? 1 : 0

      ancestors = nested_replies_walk(reply_to_post_number)

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
          removed: subtree_size,
          whisper_removed: whisper_subtree_size,
          is_whisper: is_whisper,
        )
      end
    end

    NestedViewPostStat.where(post_id: id).delete_all
  end

  def nested_replies_subtree_sizes
    stat =
      NestedViewPostStat.where(post_id: id).pick(
        :total_descendant_count,
        :whisper_total_descendant_count,
      )
    is_whisper = post_type == Post.types[:whisper] ? 1 : 0
    [1 + (stat&.first || 0), is_whisper + (stat&.second || 0)]
  end

  def nested_replies_walk(start_post_number)
    return [] if start_post_number.blank?
    # Include deleted ancestors — they may still have stat rows from when they
    # were alive, and those counts need to stay consistent.
    NestedReplies.walk_ancestors(
      topic_id: topic_id,
      start_post_number: start_post_number,
      exclude_deleted: false,
    )
  end
end
