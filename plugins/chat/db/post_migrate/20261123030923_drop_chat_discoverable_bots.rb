# frozen_string_literal: true

class DropChatDiscoverableBots < ActiveRecord::Migration[8.1]
  def up
    drop_table :chat_discoverable_bots
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
