class GroupUsers < ActiveRecord::Migration
  def change
    create_table :group_users, force: true do |t|
      t.integer :group_id, null: false
      t.integer :user_id, null: false
      t.timestamps
    end

    add_index :group_users, [:group_id, :user_id], unique: true
  end
end
