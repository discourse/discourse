class AddPostIdToEmailLogs < ActiveRecord::Migration
  def change
    add_column :email_logs, :post_id, :integer, null: true
    add_column :email_logs, :topic_id, :integer, null: true
  end
end
