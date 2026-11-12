# frozen_string_literal: true

class EnsureAnonymousAndLoggedInUsersAutoGroups < ActiveRecord::Migration[8.0]
  def up
    legacy_anonymous_users_group_id = DB.query_single(<<~SQL).first
      SELECT id FROM groups WHERE name = 'anonymous_users' AND id <> 4;
    SQL

    legacy_logged_in_users_group_id = DB.query_single(<<~SQL).first
      SELECT id FROM groups WHERE name = 'logged_in_users' AND id <> 5;
    SQL

    # Make sure any existing groups with the name `anonymous_users` or
    # `logged_in_users` are renamed to avoid conflicts with the
    # new auto groups. Also make sure to rebake posts & update group mentions.
    if legacy_anonymous_users_group_id.present?
      renamed = DB.query_single(<<~SQL)
        UPDATE groups SET name = 'anonymous_users_legacy_' || id::text
        WHERE name = 'anonymous_users' AND id <> 4
        RETURNING id;
      SQL

      if renamed.present?
        Migration::GroupMentionSlugRewriter.update_posts!(
          old_slug: "anonymous_users",
          new_slug: "anonymous_users_legacy_#{renamed.first}",
          group_id: legacy_anonymous_users_group_id,
        )
      end
    end

    if legacy_logged_in_users_group_id.present?
      renamed = DB.query_single(<<~SQL)
        UPDATE groups SET name = 'logged_in_users_legacy_' || id::text
        WHERE name = 'logged_in_users' AND id <> 5
        RETURNING id;
      SQL

      if renamed.present?
        Migration::GroupMentionSlugRewriter.update_posts!(
          old_slug: "logged_in_users",
          new_slug: "logged_in_users_legacy_#{renamed.first}",
          group_id: legacy_logged_in_users_group_id,
        )
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
