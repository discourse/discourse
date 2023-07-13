# frozen_string_literal: true

class RebakeOldAvatarServiceUrls < ActiveRecord::Migration[6.1]
  def up
    # Only need to run this migration if 20220302163246
    # changed the site setting. We can determine that
    # by checking for a user_histories entry in the last
    # month

    recently_changed = DB.query_single(<<~SQL).[](0)
      SELECT 1
      FROM user_histories
      WHERE action = 3
      AND subject = 'external_system_avatars_url'
      AND previous_value LIKE '%avatars.discourse.org%'
      AND created_at > NOW() - INTERVAL '1 month'
    SQL

    execute <<~SQL if recently_changed
        UPDATE posts SET baked_version = 0
        WHERE cooked LIKE '%avatars.discourse.org%'
      SQL
  end

  def down
    # Nothing to do
  end
end
