# frozen_string_literal: true

class CreateReviewableUsers < ActiveRecord::Migration[5.2]
  def up
    # Create reviewables for approved users
    if DB.query_single("SELECT 1 FROM site_settings WHERE name = 'must_approve_users' AND value = 't'").first
      execute(<<~SQL)
        INSERT INTO reviewables (
          type,
          status,
          created_by_id,
          reviewable_by_moderator,
          target_type,
          target_id,
          created_at,
          updated_at
        )
        SELECT 'ReviewableUser',
          0,
          #{Discourse::SYSTEM_USER_ID},
          true,
          'User',
          id,
          created_at,
          created_at
        FROM users
        WHERE active AND approved = false
      SQL
    end
  end

  def down
    execute(<<~SQL)
      DELETE FROM reviewables
      WHERE type = 'ReviewableUser'
    SQL
  end
end
