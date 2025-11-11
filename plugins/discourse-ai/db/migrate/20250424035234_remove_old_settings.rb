# frozen_string_literal: true
class RemoveOldSettings < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name IN ('ai_bot_enabled_chat_bots')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
