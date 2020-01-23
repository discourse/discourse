# frozen_string_literal: true
class AddFeaturedRankToUserBadges < ActiveRecord::Migration[6.0]
  def change
    add_column :user_badges, :featured_rank, :integer, null: true

    execute <<~SQL
      WITH featured_tl_badge AS -- Find the best trust level badge for each user
      (
        SELECT user_id, max(badge_id) as badge_id
        FROM user_badges
        WHERE badge_id IN (1,2,3,4)
        GROUP BY user_id
      ),
      ranks AS ( -- Take all user badges, group by user_id and badge_id, and calculate a rank for each one
        SELECT
          user_badges.user_id,
          user_badges.badge_id,
          RANK() OVER (
            PARTITION BY user_badges.user_id -- Do a separate rank for each user
            ORDER BY BOOL_OR(badges.enabled) DESC, -- Disabled badges last
                    MAX(featured_tl_badge.user_id) NULLS LAST, -- Best tl badge first
                    CASE WHEN user_badges.badge_id IN (1,2,3,4) THEN 1 ELSE 0 END ASC, -- Non-featured tl badges last
                    MAX(badges.badge_type_id) ASC,
                    MAX(badges.grant_count) ASC,
                    user_badges.badge_id DESC
          ) rank_number
        FROM user_badges
        INNER JOIN badges ON badges.id = user_badges.badge_id
        LEFT JOIN featured_tl_badge ON featured_tl_badge.user_id = user_badges.user_id AND featured_tl_badge.badge_id = user_badges.badge_id
        GROUP BY user_badges.user_id, user_badges.badge_id
      )
      -- Now use that data to update the featured_rank column
      UPDATE user_badges SET featured_rank = rank_number
      FROM ranks WHERE ranks.badge_id = user_badges.badge_id AND ranks.user_id = user_badges.user_id
    SQL
  end
end
