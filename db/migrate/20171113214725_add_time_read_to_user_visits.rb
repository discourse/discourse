class AddTimeReadToUserVisits < ActiveRecord::Migration[5.1]
  def up
    add_column :user_visits, :time_read, :integer, null: false, default: 0 # in seconds
    add_index :user_visits, [:user_id, :visited_at, :time_read]
  end

  def down
    remove_index :user_visits, [:user_id, :visited_at, :time_read]
    remove_column :user_visits, :time_read
  end
end
