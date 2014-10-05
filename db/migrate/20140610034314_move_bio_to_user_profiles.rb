class MoveBioToUserProfiles < ActiveRecord::Migration
  def up
    add_column :user_profiles, :bio_raw, :text
    add_column :user_profiles, :bio_cooked, :text

    execute "UPDATE user_profiles SET bio_raw = subquery.bio_raw, bio_cooked = subquery.bio_cooked FROM (
      SELECT bio_raw, bio_cooked, id FROM users
    ) as subquery WHERE user_profiles.user_id = subquery.id"

    remove_column :users, :bio_raw
    remove_column :users, :bio_cooked
  end

  def down
    add_column :users, :bio_raw, :text
    add_column :users, :bio_cooked, :text

    execute "UPDATE users SET bio_raw = subquery.bio_raw, bio_cooked = subquery.bio_cooked FROM (
      SELECT bio_raw, bio_cooked, user_id FROM user_profiles
    ) as subquery WHERE users.id = subquery.user_id"

    remove_column :user_profiles, :bio_raw
    remove_column :user_profiles, :bio_cooked
  end
end
