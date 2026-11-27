# frozen_string_literal: true

class BackfillNotificationUserIds < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    last_id = 0

    loop do
      max_id = DB.query_single(<<~SQL, last_id: last_id, batch_size: BATCH_SIZE).first
            SELECT MAX(id)
            FROM (
              SELECT id
              FROM notifications
              WHERE id > :last_id
              ORDER BY id ASC
              LIMIT :batch_size
            ) s
          SQL

      break if max_id.nil?

      DB.exec(<<~SQL, min_id: last_id, max_id: max_id)
        WITH batch AS (
          SELECT id, notification_type, data::jsonb AS jb
          FROM notifications
          WHERE id > :min_id
            AND id <= :max_id
            AND data LIKE '{%'
            AND jsonb_typeof(data::jsonb) = 'object'
            AND data::jsonb ?| ARRAY[
              'original_username', 'display_username', 'username', 'username2',
              'mentioned_by_username', 'invited_by_username',
              'original_name', 'display_name', 'name', 'name2'
            ]
        ),
        rebuilt AS (
          SELECT
            b.id,
            (
              (b.jb - ARRAY[
                'original_username', 'display_username', 'username', 'username2',
                'mentioned_by_username', 'invited_by_username',
                'original_name', 'display_name', 'name', 'name2'
              ]) || jsonb_strip_nulls(jsonb_build_object(
                'original_user_id', COALESCE(
                  CASE WHEN (b.jb ->> 'original_user_id') ~ '^-?[0-9]+$' THEN (b.jb ->> 'original_user_id')::integer END,
                  u_orig.id,
                  CASE WHEN NULLIF(b.jb ->> 'original_username', '') IS NOT NULL THEN p_orig.user_id END
                ),
                'display_user_id', COALESCE(
                  CASE WHEN (b.jb ->> 'display_user_id') ~ '^-?[0-9]+$' THEN (b.jb ->> 'display_user_id')::integer END,
                  CASE
                    WHEN g_disp.id IS NULL THEN COALESCE(
                      u_disp.id,
                      CASE
                        WHEN NULLIF(b.jb ->> 'display_username', '') IS NOT NULL AND b.notification_type = 4
                          THEN COALESCE(p_orig.last_editor_id, p_orig.user_id)
                        WHEN NULLIF(b.jb ->> 'display_username', '') IS NOT NULL
                          AND (b.jb ->> 'display_username') = (b.jb ->> 'original_username')
                          THEN p_orig.user_id
                      END
                    )
                  END
                ),
                'display_label', COALESCE(
                  b.jb ->> 'display_label',
                  CASE
                    WHEN NULLIF(b.jb ->> 'display_username', '') IS NOT NULL
                      AND NULLIF(b.jb ->> 'display_user_id', '') IS NULL
                      AND u_disp.id IS NULL
                      AND (
                        g_disp.id IS NOT NULL
                        OR (
                          b.notification_type IN (2, 6, 9, 36)
                          AND (b.jb ->> 'display_username') IS DISTINCT FROM (b.jb ->> 'original_username')
                        )
                      )
                    THEN b.jb ->> 'display_username'
                  END
                ),
                'acting_user_id', COALESCE(
                  CASE WHEN (b.jb ->> 'acting_user_id') ~ '^-?[0-9]+$' THEN (b.jb ->> 'acting_user_id')::integer END,
                  u_user.id
                ),
                'user2_id', COALESCE(
                  CASE WHEN (b.jb ->> 'user2_id') ~ '^-?[0-9]+$' THEN (b.jb ->> 'user2_id')::integer END,
                  u_user2.id
                ),
                'mentioned_by_user_id', COALESCE(
                  CASE WHEN (b.jb ->> 'mentioned_by_user_id') ~ '^-?[0-9]+$' THEN (b.jb ->> 'mentioned_by_user_id')::integer END,
                  u_ment.id
                ),
                'invited_by_user_id', COALESCE(
                  CASE WHEN (b.jb ->> 'invited_by_user_id') ~ '^-?[0-9]+$' THEN (b.jb ->> 'invited_by_user_id')::integer END,
                  u_inv.id
                )
              ))
            ) AS jb
          FROM batch b
          LEFT JOIN users u_orig  ON u_orig.username_lower  = LOWER(b.jb ->> 'original_username')
          LEFT JOIN users u_disp  ON u_disp.username_lower  = LOWER(b.jb ->> 'display_username')
          LEFT JOIN groups g_disp ON LOWER(g_disp.name)     = LOWER(b.jb ->> 'display_username')
          LEFT JOIN users u_user  ON u_user.username_lower  = LOWER(b.jb ->> 'username')
          LEFT JOIN users u_user2 ON u_user2.username_lower = LOWER(b.jb ->> 'username2')
          LEFT JOIN users u_ment  ON u_ment.username_lower  = LOWER(b.jb ->> 'mentioned_by_username')
          LEFT JOIN users u_inv   ON u_inv.username_lower   = LOWER(b.jb ->> 'invited_by_username')
          LEFT JOIN posts p_orig  ON p_orig.id = CASE WHEN (b.jb ->> 'original_post_id') ~ '^[0-9]+$' THEN (b.jb ->> 'original_post_id')::bigint END
        ),
        serialized AS (
          SELECT
            id,
            jb,
            ('{' || COALESCE((SELECT string_agg(to_json(k)::text || ':' || v::text, ',') FROM jsonb_each(jb) AS e(k, v)), '') || '}') AS raw_compact
          FROM rebuilt
        )
        UPDATE notifications n
        SET data = CASE
          WHEN char_length(s.raw_compact) <= 1000 THEN s.raw_compact
          ELSE COALESCE(
            (
              SELECT '{' || COALESCE((
                SELECT string_agg(to_json(k)::text || ':' || v::text, ',')
                FROM jsonb_each(
                  jsonb_set(
                    s.jb,
                    ARRAY[longest.k],
                    to_jsonb(left(longest.val, GREATEST(0, char_length(longest.val) - (char_length(s.raw_compact) - 1000))))
                  )
                ) AS e(k, v)
              ), '') || '}'
              FROM (
                SELECT k, v AS val
                FROM jsonb_each_text(s.jb) AS t(k, v)
                WHERE jsonb_typeof(s.jb -> k) = 'string'
                ORDER BY char_length(v) DESC
                LIMIT 1
              ) longest
            ),
            s.raw_compact
          )
        END
        FROM serialized s
        WHERE n.id = s.id
      SQL

      last_id = max_id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
