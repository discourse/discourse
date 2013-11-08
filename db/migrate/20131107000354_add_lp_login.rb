class AddLpLogin < ActiveRecord::Migration
  def up
    create_table :lp_user_infos do |t|
      t.integer :user_id, :lp_user_id, null: false
      t.string :screen_name, null: false
      t.timestamps
    end

    add_index :lp_user_infos, :user_id, unique: true
    add_index :lp_user_infos, :lp_user_id, unique: true
  end

  def down
    drop_table :lp_user_infos
  end
end
