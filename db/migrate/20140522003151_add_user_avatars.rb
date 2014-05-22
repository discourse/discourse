class AddUserAvatars < ActiveRecord::Migration
  def change
    create_table :user_avatars do |t|
      t.integer :user_id, null: false
      t.integer :system_upload_id
      t.integer :custom_upload_id
      t.integer :gravatar_upload_id
      t.datetime :last_gravatar_download_attempt
      t.timestamps
    end
  end
end
