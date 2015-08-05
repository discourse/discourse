class CreatePostActionViews < ActiveRecord::Migration

  def up
    execute <<SQL
CREATE VIEW likes AS
SELECT id, post_id, user_id, created_at, updated_at, deleted_by_id, deleted_at, post_action_type_id
FROM post_actions
WHERE post_action_type_id = 2
SQL

    execute <<SQL
CREATE VIEW bookmarks AS
SELECT id, post_id, user_id, created_at, updated_at, deleted_by_id, deleted_at, post_action_type_id
FROM post_actions
WHERE post_action_type_id = 1
SQL

    execute <<SQL
CREATE VIEW flags AS
SELECT *
FROM post_actions
WHERE post_action_type_id IN (3,4,6,7,8)
SQL
  end

  def down
    execute "DROP VIEW likes"
    execute "DROP VIEW bookmarks"
    execute "DROP VIEW flags"
  end
end
