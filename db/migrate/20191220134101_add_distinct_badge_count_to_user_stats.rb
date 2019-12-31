# frozen_string_literal: true
class AddDistinctBadgeCountToUserStats < ActiveRecord::Migration[6.0]
  def change
    add_column :user_stats, :distinct_badge_count, :integer, default: 0, null: false

    execute <<~SQL
      UPDATE user_stats
      SET distinct_badge_count = x.distinct_badge_count
      FROM (
        SELECT users.id user_id, COUNT(distinct user_badges.badge_id) distinct_badge_count
        FROM users
        LEFT JOIN user_badges ON user_badges.user_id = users.id
                              AND (user_badges.badge_id IN (SELECT id FROM badges WHERE enabled))
        GROUP BY users.id
      ) x
      WHERE user_stats.user_id = x.user_id AND user_stats.distinct_badge_count <> x.distinct_badge_count
    SQL
  end
end
