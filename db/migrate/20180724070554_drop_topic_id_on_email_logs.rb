class DropTopicIdOnEmailLogs < ActiveRecord::Migration[5.2]
  def change
    remove_index :email_logs, :topic_id
  end
end
