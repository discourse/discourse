# frozen_string_literal: true

class MigrateDraftsToChatDrafts < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO chat_drafts(user_id, chat_channel_id, data, created_at, updated_at)
      SELECT user_id, SUBSTRING(draft_key, LENGTH('chat_') + 1)::integer chat_channel_id, data, created_at, updated_at
      FROM drafts
      WHERE draft_key LIKE 'chat_%'
    SQL

    execute <<~SQL
      DELETE FROM drafts
      WHERE draft_key LIKE 'chat_%'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
