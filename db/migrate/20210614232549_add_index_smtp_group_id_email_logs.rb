# frozen_string_literal: true

class AddIndexSmtpGroupIdEmailLogs < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
      idx_email_logs_on_smtp_group_id ON email_logs USING btree (smtp_group_id)
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS idx_email_logs_on_smtp_group_id"
  end
end
