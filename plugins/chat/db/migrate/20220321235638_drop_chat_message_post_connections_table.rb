# frozen_string_literal: true

require "migration/table_dropper"

class DropChatMessagePostConnectionsTable < ActiveRecord::Migration[6.1]
  def up
    Migration::TableDropper.execute_drop("chat_message_post_connections")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
