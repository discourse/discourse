# frozen_string_literal: true

class RemoveEmailStatusesTable < ActiveRecord::Migration[7.0]
  def up
    remove_index :chat_message_email_statuses, :status
    remove_index :chat_message_email_statuses, %i[user_id chat_message_id]

    Migration::TableDropper.execute_drop("chat_message_email_statuses")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
