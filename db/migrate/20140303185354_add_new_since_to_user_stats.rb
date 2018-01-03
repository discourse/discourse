class AddNewSinceToUserStats < ActiveRecord::Migration[4.2]
  def change
    add_column :user_stats, :new_since, :datetime
    execute "UPDATE user_stats AS us
               SET new_since = u.created_at
             FROM users AS u
              WHERE u.id = us.user_id"
    change_column :user_stats, :new_since, :datetime, null: false
  end
end
