# frozen_string_literal: true
class CopyUsersSeenNotificationIdValues < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    min_id, max_id = execute("SELECT MIN(id), MAX(id) FROM users")[0].values
    batch_size = 10_000

    (min_id..max_id).step(batch_size) { |start_id| execute <<~SQL.squish } if min_id && max_id
        UPDATE users
        SET new_seen_notification_id = seen_notification_id
        WHERE id >= #{start_id} AND id < #{start_id + batch_size} AND new_seen_notification_id != seen_notification_id
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
