# frozen_string_literal: true

class HideUserTipsOnlyForExistingUsersWithMoreThanTenPosts < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE user_options
      SET seen_popups = '{}'
      FROM user_stats
      WHERE user_options.user_id = user_stats.user_id
        AND user_stats.post_count < 10
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
