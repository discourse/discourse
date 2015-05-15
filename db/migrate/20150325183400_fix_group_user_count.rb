class FixGroupUserCount < ActiveRecord::Migration
  def change
    execute "UPDATE groups g SET user_count = (SELECT COUNT(user_id) FROM group_users gu WHERE gu.group_id = g.id)"
  end
end
