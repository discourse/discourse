# frozen_string_literal: true

class RestoreClobberedPatronBadge < ActiveRecord::Migration[8.1]
  PATRON_QUERY =
    "select user_id, created_at granted_at, NULL post_id from group_users where group_id = ( select g.id from groups g where g.name = 'patrons' )"

  # Badges are seeded by name, and another plugin shipped a badge called Patron.
  # Where that overwrote this one, put back the columns the seed rewrote. The
  # text, whether it is listed and whether it is enabled were never touched, so
  # they are left as the site has them. 1 is gold and 2 is the community group.
  def up
    return if DB.query_single("SELECT 1 FROM groups WHERE name = 'patrons'").blank?

    DB.exec(<<~SQL, query: PATRON_QUERY)
      UPDATE badges
      SET query = :query,
          badge_type_id = 1,
          badge_grouping_id = 2,
          auto_revoke = true,
          system = false,
          multiple_grant = false,
          target_posts = false,
          show_posts = false,
          trigger = 0
      WHERE name = 'Patron' AND query LIKE '%voice_sessions%'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
