class AddUserAvatars < ActiveRecord::Migration
  def up
    create_table :user_avatars do |t|
      t.integer :user_id, null: false
      t.integer :system_upload_id
      t.integer :custom_upload_id
      t.integer :gravatar_upload_id
      t.datetime :last_gravatar_download_attempt
      t.timestamps
    end

    add_index :user_avatars, [:user_id]

    execute <<SQL
   INSERT INTO user_avatars(user_id, custom_upload_id)
   SELECT id, uploaded_avatar_id
   FROM users
SQL
  end

  def down
    drop_table :user_avatars
  end
end
