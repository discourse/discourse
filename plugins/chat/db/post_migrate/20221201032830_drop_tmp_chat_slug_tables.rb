# frozen_string_literal: true

class DropTmpChatSlugTables < ActiveRecord::Migration[7.0]
  def up
    DB.exec("DROP TABLE IF EXISTS tmp_chat_channel_slugs")
    DB.exec("DROP TABLE IF EXISTS tmp_chat_channel_slugs_conflicts")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
