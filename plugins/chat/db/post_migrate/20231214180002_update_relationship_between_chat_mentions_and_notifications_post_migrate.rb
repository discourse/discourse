# frozen_string_literal: true

class UpdateRelationshipBetweenChatMentionsAndNotificationsPostMigrate < ActiveRecord::Migration[
  7.0
]
  disable_ddl_transaction!
  BATCH_SIZE = 5000

  def up
    begin
      inserted_count = DB.exec(<<~SQL, batch_size: BATCH_SIZE)
        INSERT INTO chat_mention_notifications(chat_mention_id, notification_id)
        SELECT cm.id, cm.notification_id
        FROM chat_mentions cm
        LEFT JOIN chat_mention_notifications cmn ON cmn.chat_mention_id = cm.id
        WHERE cm.notification_id IS NOT NULL and cmn.chat_mention_id IS NULL
        LIMIT :batch_size;
      SQL
    end while inserted_count > 0
  end

  def down
  end
end
