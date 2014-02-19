class AddSkippedToEmailLogs < ActiveRecord::Migration
  def change
    add_column :email_logs, :skipped, :boolean, default: :false
    add_column :email_logs, :skipped_reason, :string
    add_index  :email_logs, [:skipped, :created_at]
  end
end
