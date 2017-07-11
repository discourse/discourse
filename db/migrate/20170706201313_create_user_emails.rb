class CreateUserEmails < ActiveRecord::Migration
  def up
    create_table :user_emails do |t|
      t.integer :user_id
      t.string :email, limit: 513
      t.timestamps
    end
    add_index :user_emails, :user_id
    execute "CREATE UNIQUE INDEX index_user_emails_on_email ON user_emails ((lower(email)));"
    change_table :users do |t|
      t.integer :primary_email_id
    end
    add_index :users, :primary_email_id
  end

  def down
    change_table :users do |t|
      t.remove :primary_email_id
    end
    drop_table :user_emails
  end
end
