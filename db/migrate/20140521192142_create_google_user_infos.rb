class CreateGoogleUserInfos < ActiveRecord::Migration
  def change
    create_table :google_user_infos do |t|
      t.integer :user_id, null: false
      t.string :google_user_id, null: false
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :gender
      t.string :name
      t.string :link
      t.string :profile_link
      t.string :picture

      t.timestamps
    end
    add_index :google_user_infos, :user_id, unique: true
    add_index :google_user_infos, :google_user_id, unique: true
  end
end
