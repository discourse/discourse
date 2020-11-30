# frozen_string_literal: true

class MakeImapSyncLogColsNotNull < ActiveRecord::Migration[6.0]
  def change
    change_column_null :imap_sync_logs, :message, false
    change_column_null :imap_sync_logs, :level, false
  end
end
