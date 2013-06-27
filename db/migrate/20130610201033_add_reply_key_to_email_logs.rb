class AddReplyKeyToEmailLogs < ActiveRecord::Migration
  def change
    add_column :email_logs, :reply_key, :string, limit: 32
    add_index :email_logs, :reply_key
  end
end
