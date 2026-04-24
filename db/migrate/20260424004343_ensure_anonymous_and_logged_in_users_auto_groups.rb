# frozen_string_literal: true

class EnsureAnonymousAndLoggedInUsersAutoGroups < ActiveRecord::Migration[8.0]
  def up
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
end
