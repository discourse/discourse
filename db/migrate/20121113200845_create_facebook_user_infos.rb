class CreateFacebookUserInfos < ActiveRecord::Migration[4.2]
  def change
    create_table :facebook_user_infos do |t|
      t.integer :user_id, null: false
      t.integer :facebook_user_id, null: false
      t.string :username, null: false
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :gender
      t.string :name
      t.string :link

      t.timestamps null: false
    end
    add_index :facebook_user_infos, :user_id, unique: true
    add_index :facebook_user_infos, :facebook_user_id, unique: true
  end
end
