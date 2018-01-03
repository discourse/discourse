class CreateInstagramUserInfos < ActiveRecord::Migration[4.2]
  def change
    create_table :instagram_user_infos do |t|
      t.integer :user_id
      t.string :screen_name
      t.integer :instagram_user_id

      t.timestamps null: false
    end
  end
end
