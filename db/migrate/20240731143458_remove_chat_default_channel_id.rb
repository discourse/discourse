# frozen_string_literal: true
class RemoveChatDefaultChannelId < ActiveRecord::Migration[7.1]
  def up
    execute "DELETE FROM site_settings WHERE name = 'chat_default_channel_id'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
