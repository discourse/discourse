class AddReportsIndexToUserVisits < ActiveRecord::Migration
  def up
    add_index :user_visits, [:visited_at, :mobile]
  end

  def down
    remove_index :user_visits, [:visited_at, :mobile]
  end
end
