# frozen_string_literal: true

class CleanupStrandedPmNotifications < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    loop do
      count = DB.exec(<<~SQL, batch_size: BATCH_SIZE)
        DELETE FROM notifications
        WHERE id IN (
          SELECT n.id
          FROM notifications n
          INNER JOIN topics t ON t.id = n.topic_id
          WHERE t.archetype = 'private_message'
            AND NOT EXISTS (
              SELECT 1 FROM topic_allowed_users tau
              WHERE tau.topic_id = n.topic_id AND tau.user_id = n.user_id
            )
            AND NOT EXISTS (
              SELECT 1 FROM topic_allowed_groups tag
              INNER JOIN group_users gu ON gu.group_id = tag.group_id
              WHERE tag.topic_id = n.topic_id AND gu.user_id = n.user_id
            )
          LIMIT :batch_size
        )
      SQL

      break if count == 0
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
