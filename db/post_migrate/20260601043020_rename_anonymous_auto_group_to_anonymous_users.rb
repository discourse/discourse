# frozen_string_literal: true

class RenameAnonymousAutoGroupToAnonymousUsers < ActiveRecord::Migration[8.0]
  # The `anonymous` auto group (id 4) was introduced in
  # 20260424004343_ensure_anonymous_and_logged_in_users_auto_groups.rb. It
  # should have been named `anonymous_users` for consistency with
  # `logged_in_users`, so this renames the existing row and rewrites any posts
  # that mention it.
  def up
    legacy_anonymous_users_group_id = DB.query_single(<<~SQL).first
      SELECT id FROM groups WHERE name = 'anonymous_users' AND id <> 4;
    SQL

    # Move any pre-existing, non-auto group that happens to already be named
    # `anonymous_users` out of the way so the rename below doesn't hit the unique
    # name constraint. Rebake its mentions to point at the renamed slug.
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

    # Rename the auto group itself, then rewrite any `@anonymous` mentions of it
    # to `@anonymous_users`.
    renamed = DB.query_single(<<~SQL)
      UPDATE groups SET name = 'anonymous_users'
      WHERE id = 4 AND name = 'anonymous'
      RETURNING id;
    SQL

    if renamed.present?
      Migration::GroupMentionSlugRewriter.update_posts!(
        old_slug: "anonymous",
        new_slug: "anonymous_users",
        group_id: 4,
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
