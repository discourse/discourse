# frozen_string_literal: true

class SetTypeAndTargetIdOnChatMentionsPostMigrate < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  BATCH_SIZE = 5000

  def up
    # we're setting it again in post-migration
    # in case some mentions have been created after we run
    # this query the first time in the regular migration
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
