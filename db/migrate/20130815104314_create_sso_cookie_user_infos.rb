class CreateSsoCookieUserInfos < ActiveRecord::Migration
  def change
    create_table :sso_cookie_user_infos do |t|
      t.integer :user_id, null: false
      t.string :sso_id, null: false

      t.timestamps
    end

    add_index :sso_cookie_user_infos, [:sso_id], unique: true
    add_index :sso_cookie_user_infos, [:user_id], unique: true
  end
end
