class CreateOauth2UserInfos < ActiveRecord::Migration[4.2]
  def change
    create_table :oauth2_user_infos do |t|
      t.integer :user_id, null: false
      t.string :uid, null: false
      t.string :provider, null: false
      t.string :email
      t.string :name
      t.timestamps null: false
    end

    add_index :oauth2_user_infos, [:uid, :provider], unique: true
  end
end
