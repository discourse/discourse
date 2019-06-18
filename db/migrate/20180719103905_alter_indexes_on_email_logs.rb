# frozen_string_literal: true

class AlterIndexesOnEmailLogs < ActiveRecord::Migration[5.2]
  def change
    remove_index :email_logs,
      name: "index_email_logs_on_user_id_and_created_at",
      column: [:user_id, :created_at]

    add_index :email_logs, :user_id

    remove_index :email_logs, [:skipped, :created_at]
    add_index :email_logs, [:skipped, :bounced, :created_at]
  end
end
