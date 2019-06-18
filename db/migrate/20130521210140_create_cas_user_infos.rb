# frozen_string_literal: true

class CreateCasUserInfos < ActiveRecord::Migration[4.2]
  def change
    create_table :cas_user_infos do |t|
      t.integer :user_id, null: false
      t.string :cas_user_id, null: false
      t.string :username, null: false
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :gender
      t.string :name
      t.string :link

      t.timestamps null: false
    end
    add_index :cas_user_infos, :user_id, unique: true
    add_index :cas_user_infos, :cas_user_id, unique: true
  end
end
