class AddGithubUserInfo < ActiveRecord::Migration
  def change
    create_table :github_user_infos do  |t|
      t.integer :user_id, null: false
      t.string :screen_name, null: false
      t.integer :github_user_id, null: false
      t.timestamps
    end

    add_index :github_user_infos, [:github_user_id], unique: true
    add_index :github_user_infos, [:user_id], unique: true
  end
end
