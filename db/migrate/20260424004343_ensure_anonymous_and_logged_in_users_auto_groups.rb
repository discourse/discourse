# frozen_string_literal: true

class EnsureAnonymousAndLoggedInUsersAutoGroups < ActiveRecord::Migration[8.0]
  def up
    legacy_anonymous_group_id = DB.query_single(<<~SQL).first
      SELECT id FROM groups WHERE name = 'anonymous' AND id <> 4;
    SQL

    legacy_logged_in_users_group_id = DB.query_single(<<~SQL).first
      SELECT id FROM groups WHERE name = 'logged_in_users' AND id <> 5;
    SQL

    # Make sure any existing groups with the name `anonymous` or
    # `logged_in_users` are renamed to avoid conflicts with the
    # new auto groups. Also make sure to rebake posts & update group mentions.
    if legacy_anonymous_group_id.present?
      execute(<<~SQL)
        UPDATE groups SET name = 'anonymous_legacy_' || id::text
        WHERE name = 'anonymous' AND id <> 4;
      SQL

      update_group_mentions(
        "anonymous",
        "anonymous_legacy_#{legacy_anonymous_group_id}",
        legacy_anonymous_group_id,
      )
    end

    if legacy_logged_in_users_group_id.present?
      execute(<<~SQL)
        UPDATE groups SET name = 'logged_in_users_legacy_' || id::text
        WHERE name = 'logged_in_users' AND id <> 5;
      SQL

      update_group_mentions(
        "logged_in_users",
        "logged_in_users_legacy_#{legacy_logged_in_users_group_id}",
        legacy_logged_in_users_group_id,
      )
    end

    # The `anonymous` (id 4) and `logged_in_users` (id 5) auto groups are
    # pseudogroups — they have no group_users rows; membership is implicit.
    # Seed the rows here so callers that look them up by id don't fail before
    # db/fixtures/002_groups.rb runs.
    execute(<<~SQL)
      INSERT INTO groups (id, name, automatic, visibility_level, created_at, updated_at)
      VALUES
        (4, 'anonymous', true, 3, NOW(), NOW()),
        (5, 'logged_in_users', true, 3, NOW(), NOW())
      ON CONFLICT (id) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def update_group_mentions(old_slug, new_slug, legacy_group_id)
    DB.exec(<<~SQL, old_slug:, new_slug:, group_id: legacy_group_id)
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
