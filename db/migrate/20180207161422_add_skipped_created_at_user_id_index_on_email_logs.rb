# frozen_string_literal: true

class AddSkippedCreatedAtUserIdIndexOnEmailLogs < ActiveRecord::Migration[5.1]
  def up
    execute "CREATE INDEX idx_email_logs_user_created_filtered ON email_logs(user_id, created_at) WHERE skipped = 'f'"
  end
  def down
    execute "DROP INDEX idx_email_logs_user_created_filtered"
  end
end
