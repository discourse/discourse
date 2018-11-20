class AddBadgeGrantedTitleToUserProfile < ActiveRecord::Migration[4.2]
  def up
    add_column :user_profiles, :badge_granted_title, :boolean, default: false

    execute "UPDATE user_profiles SET badge_granted_title = true
    WHERE EXISTS (
      SELECT 1 FROM users WHERE users.id = user_id AND title IN ('Leader', 'Regular')
    )"

    execute "UPDATE user_profiles SET badge_granted_title = true
    WHERE EXISTS (
      SELECT 1 FROM users WHERE users.id = user_id AND title IN (SELECT name FROM badges WHERE allow_title)
    )"
  end

  def down
    remove_column :user_profiles, :badge_granted_title
  end
end
