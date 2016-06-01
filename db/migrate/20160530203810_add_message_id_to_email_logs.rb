class AddMessageIdToEmailLogs < ActiveRecord::Migration
  def change
    add_column :email_logs, :message_id, :string
    add_index :email_logs, :message_id
  end
end
