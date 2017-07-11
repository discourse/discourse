class MigrateEmailsToUserEmails < ActiveRecord::Migration
  def up
    execute "INSERT INTO user_emails (user_id, email, created_at, updated_at) SELECT id, email, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM users WHERE users.id != -1"
    execute "UPDATE users SET primary_email_id = user_emails.id FROM user_emails WHERE user_emails.user_id = users.id"
    change_column_null :users, :primary_email_id, false
    change_column_null :users, :email, true
  end

  def down
    change_column_null :users, :email, false
    change_column_null :users, :primary_email_id, true
    execute "UPDATE users SET primary_email_id = NULL"
    execute "DELETE FROM user_emails"
  end
end
