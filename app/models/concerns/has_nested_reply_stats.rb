# frozen_string_literal: true

module HasNestedReplyStats
  extend ActiveSupport::Concern

  included do
    after_create :nested_replies_increment_stats
    after_destroy :nested_replies_decrement_stats
    after_update :nested_replies_apply_structural_changes
    after_commit :nested_replies_refresh_after_update, on: :update
  end

  private

  def nested_replies_increment_stats
    return unless nested_replies_tracks_stats?
    return if reply_to_post_number.blank?

    total, whisper = NestedReplies::StructuralStats.weights_for(post_type, action_code)
    return if total.zero? && whisper.zero?

    NestedReplies::StructuralStats.with_topic_lock(topic_id) do
      ancestors = nested_replies_walk(reply_to_post_number)
      next if ancestors.empty?

      ancestor_ids = ancestors.map(&:id).uniq
      direct_parent_id = ancestors.find { |ancestor| ancestor.depth == 1 }&.id

      DB.exec(
        <<~SQL,
          INSERT INTO nested_view_post_stats (
            post_id,
            direct_reply_count,
            total_descendant_count,
            whisper_direct_reply_count,
            whisper_total_descendant_count,
            created_at,
            updated_at
          )
          SELECT ancestor_id,
                 CASE WHEN ancestor_id = :parent_id THEN :total ELSE 0 END,
                 :total,
                 CASE WHEN ancestor_id = :parent_id THEN :whisper ELSE 0 END,
                 :whisper,
                 NOW(),
                 NOW()
          FROM unnest(ARRAY[:ids]::int[]) AS ancestor_id
          ON CONFLICT (post_id) DO UPDATE SET
            total_descendant_count = nested_view_post_stats.total_descendant_count + :total,
            direct_reply_count = nested_view_post_stats.direct_reply_count +
              CASE WHEN nested_view_post_stats.post_id = :parent_id THEN :total ELSE 0 END,
            whisper_total_descendant_count =
              nested_view_post_stats.whisper_total_descendant_count + :whisper,
            whisper_direct_reply_count = nested_view_post_stats.whisper_direct_reply_count +
              CASE WHEN nested_view_post_stats.post_id = :parent_id THEN :whisper ELSE 0 END,
            updated_at = NOW()
        SQL
        ids: ancestor_ids,
        parent_id: direct_parent_id,
        total: total,
        whisper: whisper,
      )
    end
  end

  def nested_replies_decrement_stats
    return unless nested_replies_tracks_stats?

    NestedReplies::StructuralStats.with_topic_lock(topic_id) do
      if reply_to_post_number.present?
        subtree_total, subtree_whisper = nested_replies_subtree_sizes
        total, whisper = NestedReplies::StructuralStats.weights_for(post_type, action_code)
        ancestors = nested_replies_walk(reply_to_post_number)

        if ancestors.present?
          ancestor_ids = ancestors.map(&:id).uniq
          direct_parent_id = ancestors.find { |ancestor| ancestor.depth == 1 }&.id

          DB.exec(
            <<~SQL,
              UPDATE nested_view_post_stats
              SET total_descendant_count = GREATEST(total_descendant_count - :subtree_total, 0),
                  direct_reply_count = GREATEST(
                    direct_reply_count -
                      CASE WHEN post_id = :parent_id THEN :total ELSE 0 END,
                    0
                  ),
                  whisper_total_descendant_count = GREATEST(
                    whisper_total_descendant_count - :subtree_whisper,
                    0
                  ),
                  whisper_direct_reply_count = GREATEST(
                    whisper_direct_reply_count -
                      CASE WHEN post_id = :parent_id THEN :whisper ELSE 0 END,
                    0
                  ),
                  updated_at = NOW()
              WHERE post_id = ANY(ARRAY[:ids]::int[])
            SQL
            ids: ancestor_ids,
            parent_id: direct_parent_id,
            subtree_total: subtree_total,
            subtree_whisper: subtree_whisper,
            total: total,
            whisper: whisper,
          )
        end
      end

      NestedViewPostStat.where(post_id: id).delete_all
    end

    nested_replies_enqueue_structural_rebuild
  end

  def nested_replies_apply_structural_changes
    return if saved_change_to_topic_id?
    return unless nested_replies_tracks_stats?

    parent_changed = saved_change_to_reply_to_post_number?
    post_type_changed = saved_change_to_post_type?
    action_code_changed = saved_change_to_action_code?
    return unless parent_changed || post_type_changed || action_code_changed

    previous_parent = reply_to_post_number_before_last_save
    previous_post_type = post_type_before_last_save
    previous_action_code = action_code_before_last_save

    NestedReplies::StructuralStats.with_topic_lock(topic_id) do
      if parent_changed
        nested_replies_apply_reparent(previous_parent, previous_post_type, previous_action_code)
      else
        nested_replies_apply_visibility_change(previous_post_type, previous_action_code)
      end
    end
  end

  def nested_replies_apply_reparent(previous_parent, previous_post_type, previous_action_code)
    descendant_total, descendant_whisper = nested_replies_cached_descendant_sizes
    previous_total, previous_whisper =
      NestedReplies::StructuralStats.weights_for(previous_post_type, previous_action_code)
    current_total, current_whisper =
      NestedReplies::StructuralStats.weights_for(post_type, action_code)

    previous_subtree_total = descendant_total + previous_total
    previous_subtree_whisper = descendant_whisper + previous_whisper
    current_subtree_total = descendant_total + current_total
    current_subtree_whisper = descendant_whisper + current_whisper

    previous_ancestors = nested_replies_walk(previous_parent)
    current_ancestors = nested_replies_walk(reply_to_post_number)
    previous_ids = previous_ancestors.map(&:id).uniq
    current_ids = current_ancestors.map(&:id).uniq

    nested_replies_decrement_ancestors(
      previous_ids - current_ids,
      previous_subtree_total,
      previous_subtree_whisper,
    )
    nested_replies_increment_ancestors(
      current_ids - previous_ids,
      current_subtree_total,
      current_subtree_whisper,
    )

    nested_replies_adjust_ancestors(
      previous_ids & current_ids,
      current_total - previous_total,
      current_whisper - previous_whisper,
    )

    previous_direct_parent_id = previous_ancestors.find { |ancestor| ancestor.depth == 1 }&.id
    current_direct_parent_id = current_ancestors.find { |ancestor| ancestor.depth == 1 }&.id

    nested_replies_adjust_direct_parent(
      previous_direct_parent_id,
      -previous_total,
      -previous_whisper,
    )
    nested_replies_adjust_direct_parent(
      current_direct_parent_id,
      current_total,
      current_whisper,
      insert_missing: true,
    )
  end

  def nested_replies_apply_visibility_change(previous_post_type, previous_action_code)
    previous_total, previous_whisper =
      NestedReplies::StructuralStats.weights_for(previous_post_type, previous_action_code)
    current_total, current_whisper =
      NestedReplies::StructuralStats.weights_for(post_type, action_code)
    total_delta = current_total - previous_total
    whisper_delta = current_whisper - previous_whisper
    return if total_delta.zero? && whisper_delta.zero?

    ancestors = nested_replies_walk(reply_to_post_number)
    ancestor_ids = ancestors.map(&:id).uniq
    nested_replies_adjust_ancestors(ancestor_ids, total_delta, whisper_delta)

    direct_parent_id = ancestors.find { |ancestor| ancestor.depth == 1 }&.id
    nested_replies_adjust_direct_parent(
      direct_parent_id,
      total_delta,
      whisper_delta,
      insert_missing: total_delta.positive? || whisper_delta.positive?,
    )
  end

  def nested_replies_decrement_ancestors(ids, total, whisper)
    return if ids.empty? || (total.zero? && whisper.zero?)

    DB.exec(<<~SQL, ids: ids, total: total, whisper: whisper)
        UPDATE nested_view_post_stats
        SET total_descendant_count = GREATEST(total_descendant_count - :total, 0),
            whisper_total_descendant_count = GREATEST(
              whisper_total_descendant_count - :whisper,
              0
            ),
            updated_at = NOW()
        WHERE post_id = ANY(ARRAY[:ids]::int[])
      SQL
  end

  def nested_replies_increment_ancestors(ids, total, whisper)
    return if ids.empty? || (total.zero? && whisper.zero?)

    DB.exec(<<~SQL, ids: ids, total: total, whisper: whisper)
        INSERT INTO nested_view_post_stats (
          post_id,
          direct_reply_count,
          total_descendant_count,
          whisper_direct_reply_count,
          whisper_total_descendant_count,
          created_at,
          updated_at
        )
        SELECT ancestor_id, 0, :total, 0, :whisper, NOW(), NOW()
        FROM unnest(ARRAY[:ids]::int[]) AS ancestor_id
        ON CONFLICT (post_id) DO UPDATE SET
          total_descendant_count = nested_view_post_stats.total_descendant_count + :total,
          whisper_total_descendant_count =
            nested_view_post_stats.whisper_total_descendant_count + :whisper,
          updated_at = NOW()
      SQL
  end

  def nested_replies_adjust_existing_ancestors(ids, total_delta, whisper_delta)
    return if ids.empty? || (total_delta.zero? && whisper_delta.zero?)

    DB.exec(<<~SQL, ids: ids, total_delta: total_delta, whisper_delta: whisper_delta)
        UPDATE nested_view_post_stats
        SET total_descendant_count = GREATEST(total_descendant_count + :total_delta, 0),
            whisper_total_descendant_count = GREATEST(
              whisper_total_descendant_count + :whisper_delta,
              0
            ),
            updated_at = NOW()
        WHERE post_id = ANY(ARRAY[:ids]::int[])
      SQL
  end

  def nested_replies_adjust_ancestors(ids, total_delta, whisper_delta)
    if total_delta >= 0 && whisper_delta >= 0
      nested_replies_increment_ancestors(ids, total_delta, whisper_delta)
    else
      nested_replies_adjust_existing_ancestors(ids, total_delta, whisper_delta)
    end
  end

  def nested_replies_adjust_direct_parent(
    parent_id,
    total_delta,
    whisper_delta,
    insert_missing: false
  )
    return if parent_id.blank? || (total_delta.zero? && whisper_delta.zero?)

    if insert_missing
      DB.exec(<<~SQL, parent_id: parent_id, total_delta: total_delta, whisper_delta: whisper_delta)
          INSERT INTO nested_view_post_stats (
            post_id,
            direct_reply_count,
            total_descendant_count,
            whisper_direct_reply_count,
            whisper_total_descendant_count,
            created_at,
            updated_at
          )
          VALUES (:parent_id, :total_delta, 0, :whisper_delta, 0, NOW(), NOW())
          ON CONFLICT (post_id) DO UPDATE SET
            direct_reply_count = GREATEST(
              nested_view_post_stats.direct_reply_count + :total_delta,
              0
            ),
            whisper_direct_reply_count = GREATEST(
              nested_view_post_stats.whisper_direct_reply_count + :whisper_delta,
              0
            ),
            updated_at = NOW()
        SQL
    else
      DB.exec(<<~SQL, parent_id: parent_id, total_delta: total_delta, whisper_delta: whisper_delta)
          UPDATE nested_view_post_stats
          SET direct_reply_count = GREATEST(direct_reply_count + :total_delta, 0),
              whisper_direct_reply_count = GREATEST(
                whisper_direct_reply_count + :whisper_delta,
                0
              ),
              updated_at = NOW()
          WHERE post_id = :parent_id
        SQL
    end
  end

  def nested_replies_subtree_sizes
    descendant_total, descendant_whisper = nested_replies_cached_descendant_sizes
    total, whisper = NestedReplies::StructuralStats.weights_for(post_type, action_code)
    [descendant_total + total, descendant_whisper + whisper]
  end

  def nested_replies_cached_descendant_sizes
    stat =
      NestedViewPostStat.where(post_id: id).pick(
        :total_descendant_count,
        :whisper_total_descendant_count,
      )
    [stat&.first || 0, stat&.second || 0]
  end

  def nested_replies_refresh_after_update
    if previous_changes.key?("topic_id")
      NestedReplies::RecalculationQueue.enqueue_topic_rebuilds(
        previous_changes["topic_id"].compact.uniq,
        structural: true,
        hot: true,
      )
      return
    end

    return unless nested_replies_tracks_stats?

    parent_changed = previous_changes.key?("reply_to_post_number")
    structural_visibility_changed =
      previous_changes.key?("post_type") || previous_changes.key?("action_code")
    hot_visibility_changed = previous_changes.key?("hidden") || structural_visibility_changed

    if parent_changed
      NestedReplies::RecalculationQueue.enqueue_topic_rebuilds(
        [topic_id],
        structural: true,
        hot: true,
      )
    elsif structural_visibility_changed
      NestedReplies::RecalculationQueue.enqueue_topic_rebuilds(
        [topic_id],
        structural: true,
        hot: false,
      )
      NestedReplies::RecalculationQueue.enqueue_hot_post(id)
    elsif hot_visibility_changed
      NestedReplies::RecalculationQueue.enqueue_hot_post(id)
    end
  end

  def nested_replies_enqueue_structural_rebuild
    topic_id = self.topic_id

    DB.after_commit do
      NestedReplies::RecalculationQueue.enqueue_topic_rebuilds(
        [topic_id],
        structural: true,
        hot: false,
      )
    end
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

  def nested_replies_tracks_stats?
    SiteSetting.nested_replies_enabled && topic&.nested_view?
  end
end
