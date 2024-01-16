# frozen_string_literal: true

class SetTypeAndTargetIdOnChatMentions < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  BATCH_SIZE = 5000

  def up
    begin
      updated_count = DB.exec(<<~SQL, batch_size: BATCH_SIZE)
        WITH cte AS (SELECT id, user_id
                     FROM chat_mentions
                     WHERE type IS NULL AND target_id IS NULL
                     LIMIT :batch_size)
        UPDATE chat_mentions
        SET type = 'Chat::UserMention', target_id = cte.user_id
        FROM cte
        WHERE chat_mentions.id = cte.id;
      SQL
    end while updated_count > 0
  end

  def down
  end
end
