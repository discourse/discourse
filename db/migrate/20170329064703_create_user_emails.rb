class CreateUserEmails < ActiveRecord::Migration
  def up
    create_table :user_emails do |t|
      t.references :user
      t.string :email, limit: 513
      t.timestamps
    end
    execute "INSERT INTO user_emails (user_id, email, created_at, updated_at) SELECT id, email, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM users"
    change_table :users do |t|
      t.remove :email
      t.integer :primary_email_id
    end
    execute "UPDATE users SET primary_email_id = user_emails.id FROM user_emails WHERE user_emails.user_id = users.id"
    change_column_null :users, :primary_email_id, false
  end

  def down
    change_table :users do |t|
      t.string :email, limit: 513
      t.remove :primary_email_id
    end
    execute "UPDATE users SET email = user_emails.email FROM user_emails WHERE user_emails.user_id = users.id"
    change_column_null :users, :email, false
    drop_table :user_emails
  end
end
