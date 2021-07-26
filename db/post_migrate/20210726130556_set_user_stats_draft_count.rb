# frozen_string_literal: true

class SetUserStatsDraftCount < ActiveRecord::Migration[6.1]
  def change
    execute <<~SQL
      UPDATE user_stats
      SET draft_count = new_user_stats.draft_count
      FROM (SELECT user_stats.user_id, COUNT(drafts.id) draft_count
            FROM user_stats
            LEFT JOIN drafts ON user_stats.user_id = drafts.user_id
            GROUP BY user_stats.user_id) new_user_stats
      WHERE user_stats.user_id = new_user_stats.user_id
        AND user_stats.draft_count <> new_user_stats.draft_count
    SQL
  end
end
