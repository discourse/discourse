# frozen_string_literal: true

class AddTwitterUserInfo < ActiveRecord::Migration[4.2]
  def change
    create_table :twitter_user_infos do  |t|
      t.integer :user_id, null: false
      t.string :screen_name, null: false
      t.integer :twitter_user_id, null: false
      t.timestamps null: false
    end

    add_index :twitter_user_infos, [:twitter_user_id], unique: true
    add_index :twitter_user_infos, [:user_id], unique: true
  end
end
