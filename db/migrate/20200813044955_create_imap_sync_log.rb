# frozen_string_literal: true

class CreateImapSyncLog < ActiveRecord::Migration[6.0]
  def change
    create_table :imap_sync_logs do |t|
      t.integer :level
      t.string :message
      t.bigint :group_id, null: true

      t.timestamps
    end

    add_index :imap_sync_logs, :group_id
    add_index :imap_sync_logs, :level
  end
end
