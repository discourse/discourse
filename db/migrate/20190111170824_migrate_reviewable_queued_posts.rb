# frozen_string_literal: true

class MigrateReviewableQueuedPosts < ActiveRecord::Migration[5.2]
  def up
    execute(<<~SQL)
      INSERT INTO reviewables (
        type,
        status,
        created_by_id,
        reviewable_by_moderator,
        topic_id,
        category_id,
        payload,
        created_at,
        updated_at
      )
      SELECT 'ReviewableQueuedPost',
        state - 1,
        user_id,
        true,
        topic_id,
        NULLIF(REGEXP_REPLACE(post_options->>'category', '[^0-9]+', '', 'g'), '')::int,
        json_build_object(
          'old_queued_post_id', id,
          'raw', raw
        )::jsonb || post_options::jsonb,
        created_at,
        updated_at
      FROM queued_posts
    SQL

    # Migrate Created History
    execute(<<~SQL)
      INSERT INTO reviewable_histories (
        reviewable_id,
        reviewable_history_type,
        status,
        created_by_id,
        created_at,
        updated_at
      )
      SELECT r.id,
        0,
        0,
        qp.user_id,
        qp.created_at,
        qp.created_at
      FROM reviewables AS r
      INNER JOIN queued_posts AS qp ON qp.id = (payload->>'old_queued_post_id')::int
    SQL

    # Migrate Approved History
    execute(<<~SQL)
      INSERT INTO reviewable_histories (
        reviewable_id,
        reviewable_history_type,
        status,
        created_by_id,
        created_at,
        updated_at
      )
      SELECT r.id,
        1,
        1,
        qp.approved_by_id,
        qp.approved_at,
        qp.approved_at
      FROM reviewables AS r
      INNER JOIN queued_posts AS qp ON qp.id = (payload->>'old_queued_post_id')::int
      WHERE qp.state = 2
    SQL

    # Migrate Rejected History
    execute(<<~SQL)
      INSERT INTO reviewable_histories (
        reviewable_id,
        reviewable_history_type,
        status,
        created_by_id,
        created_at,
        updated_at
      )
      SELECT r.id,
        1,
        2,
        qp.rejected_by_id,
        qp.rejected_at,
        qp.rejected_at
      FROM reviewables AS r
      INNER JOIN queued_posts AS qp ON qp.id = (payload->>'old_queued_post_id')::int
      WHERE qp.state = 3
    SQL
  end

  def down
    execute(<<~SQL)
      DELETE FROM reviewable_histories
      WHERE reviewable_id IN (SELECT id FROM reviewables WHERE type = 'ReviewableQueuedPost')
    SQL

    execute(<<~SQL)
      DELETE FROM reviewables
      WHERE type = 'ReviewableQueuedPost'
    SQL
  end
end
