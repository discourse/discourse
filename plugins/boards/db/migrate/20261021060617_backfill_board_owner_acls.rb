# frozen_string_literal: true
class BackfillBoardOwnerAcls < ActiveRecord::Migration[8.1]
  def up
    return unless Migration::Helpers.existing_site?

    insert_missing_owner_acls
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def insert_missing_owner_acls
    execute <<~SQL
      INSERT INTO access_control_lists (
        target_type,
        target_id,
        owner,
        permission,
        allowed_user_ids,
        allowed_group_ids,
        created_at,
        updated_at
      )
      SELECT
        'Boards::Board',
        boards.id,
        'boards',
        'owner',
        ARRAY[boards.created_by_id]::bigint[],
        ARRAY[]::bigint[],
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM discourse_kanban_boards AS boards
      INNER JOIN users ON users.id = boards.created_by_id
      WHERE NOT EXISTS (
        SELECT 1
        FROM access_control_lists AS owner_acl
        WHERE owner_acl.target_type = 'Boards::Board'
          AND owner_acl.target_id = boards.id
          AND owner_acl.permission = 'owner'
      )
      ON CONFLICT DO NOTHING
    SQL
  end
end
