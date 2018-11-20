class RemoveEmailTokenFromUsers < ActiveRecord::Migration[4.2]
  def up
    execute "INSERT INTO email_tokens (user_id, email, token, created_at, updated_at)
              SELECT id, email, email_token, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
              FROM users WHERE email_token IS NOT NULL"

    remove_column :users, :email_token
  end

  def down
    add_column :users, :email_token, :string
    execute "DELETE FROM email_tokens"
  end
end
