class AddIndexEmailLogsOnBounced < ActiveRecord::Migration[5.2]
  def change
    add_index :email_logs, :bounced
    remove_index :email_logs, [:user_id, :created_at]
  end
end
