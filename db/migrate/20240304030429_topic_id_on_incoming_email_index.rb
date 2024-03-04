# frozen_string_literal: true
class TopicIdOnIncomingEmailIndex < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :incoming_emails, :topic_id, algorithm: :concurrently
  end
end
