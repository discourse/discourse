# frozen_string_literal: true

class RemoveDuplicateChatMentionNotifications < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # `Notification.types[:chat_mention]` — hardcoded so the migration stays
  # stable if the enum is ever renumbered.
  CHAT_MENTION_TYPE = 29

  # PR #39614 deployed on 2026-04-29 introduced a Propshaft asset lookup
  # in `Chat::Notifier.push_notification_reply_action` that raised on
  # every chat mention. `Jobs::Chat::NotifyMentioned` calls
  # `create_notification!` before `send_notifications`, so each Sidekiq
  # retry inserted another `Notification` row for the same mention. The
  # follow-up fix landed on 2026-04-30; this sweeps up rows created in
  # between.
  WINDOW_START = "2026-04-29".freeze

  def up
    affected_user_ids = DB.query_single(<<~SQL, type: CHAT_MENTION_TYPE, since: WINDOW_START)
        SELECT DISTINCT user_id
        FROM notifications
        WHERE notification_type = :type
          AND created_at >= :since
      SQL

    affected_user_ids.each do |user_id|
      DB.exec(<<~SQL, type: CHAT_MENTION_TYPE, since: WINDOW_START, user_id: user_id)
        WITH dups AS (
          SELECT
            id,
            MIN(id) OVER (PARTITION BY data) AS keep_id,
            BOOL_OR(read) OVER (PARTITION BY data) AS any_read
          FROM notifications
          WHERE notification_type = :type
            AND created_at >= :since
            AND user_id = :user_id
        ),
        to_delete AS (
          SELECT id FROM dups WHERE id <> keep_id
        ),
        cleaned_join AS (
          DELETE FROM chat_mention_notifications
          WHERE notification_id IN (SELECT id FROM to_delete)
        ),
        marked_read AS (
          UPDATE notifications n
          SET read = TRUE
          FROM dups d
          WHERE n.id = d.keep_id
            AND d.any_read
            AND NOT n.read
        )
        DELETE FROM notifications WHERE id IN (SELECT id FROM to_delete)
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
