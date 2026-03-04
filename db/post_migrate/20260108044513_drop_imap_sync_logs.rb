# frozen_string_literal: true
class DropImapSyncLogs < ActiveRecord::Migration[8.0]
  def change
    drop_table :imap_sync_logs, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
