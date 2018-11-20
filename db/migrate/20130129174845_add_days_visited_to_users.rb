class AddDaysVisitedToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :days_visited, :integer, null: false, default: 0

    execute "UPDATE users AS u SET days_visited = (SELECT COUNT(*) FROM user_visits AS uv WHERE uv.user_id = u.id)"
  end
end
