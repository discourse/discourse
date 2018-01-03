class AddMessageIdToEmailLogs < ActiveRecord::Migration[4.2]
  def change
    add_column :email_logs, :message_id, :string
    add_index :email_logs, :message_id
  end
end
