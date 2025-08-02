# frozen_string_literal: true
class TopicIdOnIncomingEmailIndex < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    remove_index :incoming_emails, :topic_id, if_exists: true
    add_index :incoming_emails, :topic_id, algorithm: :concurrently
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
