class DropReplyKeySkippedSkippedReasonFromEmailLogs < ActiveRecord::Migration[5.2]
  def up
    remove_index :email_logs, [:skipped, :bounced, :created_at]
    remove_index :email_logs, name: 'idx_email_logs_user_created_filtered'
    add_index :email_logs, [:user_id, :created_at]
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
