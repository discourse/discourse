class IndexUserBadges < ActiveRecord::Migration[4.2]
  def change
    execute 'DELETE FROM user_badges USING user_badges ub2
             WHERE  user_badges.badge_id = ub2.badge_id AND
                    user_badges.user_id = ub2.user_id AND
                    user_badges.post_id IS NOT NULL AND
                    user_badges.id < ub2.id
    '
    add_index :user_badges, [:badge_id, :user_id, :post_id], unique: true, where: 'post_id IS NOT NULL'
  end
end
