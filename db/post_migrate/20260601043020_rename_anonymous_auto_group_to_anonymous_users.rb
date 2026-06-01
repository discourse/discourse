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
      execute(<<~SQL)
        UPDATE groups SET name = 'anonymous_users_legacy_' || id::text
        WHERE name = 'anonymous_users' AND id <> 4;
      SQL

      update_group_mentions(
        "anonymous_users",
        "anonymous_users_legacy_#{legacy_anonymous_users_group_id}",
        legacy_anonymous_users_group_id,
      )
    end

    # Rename the auto group itself, then rewrite any `@anonymous` mentions of it
    # to `@anonymous_users`.
    renamed = DB.query_single(<<~SQL)
        UPDATE groups SET name = 'anonymous_users'
        WHERE id = 4 AND name = 'anonymous'
        RETURNING id;
      SQL

    update_group_mentions("anonymous", "anonymous_users", 4) if renamed.present?
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def update_group_mentions(old_slug, new_slug, group_id)
    DB.exec(<<~SQL, old_slug:, new_slug:, group_id:)
      UPDATE posts AS p  SET
          raw = regexp_replace(
            p.raw,
            '(^|\s)(@' || :old_slug || ')(\s|$)',
            E'\\1@' || :new_slug || E'\\3',
            'g'
          ),
          baked_version = NULL
        WHERE p.deleted_at IS NULL
          AND EXISTS (
            SELECT 1
            FROM group_mentions gm
            WHERE gm.post_id = p.id
              AND gm.group_id = :group_id
          )
          AND p.raw LIKE '%@' || :old_slug || '%';
    SQL
  end
end
