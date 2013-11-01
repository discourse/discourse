class AddHerokuLogin < ActiveRecord::Migration
  def up
    create_table :heroku_user_infos do |t|
      t.integer :user_id, :heroku_user_id, null: false
      t.string :screen_name, null: false
      t.timestamps
    end

    add_index :heroku_user_infos, :user_id, unique: true
    add_index :heroku_user_infos, :heroku_user_id, unique: true
  end

  def down
    drop_table :heroku_user_infos
  end
end
