# frozen_string_literal: true
class FinalizeBoardOwnerAcls < ActiveRecord::Migration[8.1]
  def up
    return unless Migration::Helpers.existing_site?

    insert_missing_owner_acls
    remove_redundant_owner_grants
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

  def remove_redundant_owner_grants
    execute <<~SQL
      DELETE FROM access_control_lists AS permission_acl
      USING access_control_lists AS owner_acl
      WHERE permission_acl.target_type = 'Boards::Board'
        AND owner_acl.target_type = permission_acl.target_type
        AND owner_acl.target_id = permission_acl.target_id
        AND owner_acl.permission = 'owner'
        AND permission_acl.permission <> 'owner'
        AND permission_acl.allowed_user_ids && owner_acl.allowed_user_ids
        AND permission_acl.allowed_user_ids <@ owner_acl.allowed_user_ids
        AND cardinality(permission_acl.allowed_group_ids) = 0
    SQL

    execute <<~SQL
      UPDATE access_control_lists AS permission_acl
      SET
        allowed_user_ids = ARRAY(
          SELECT granted_user_id
          FROM unnest(permission_acl.allowed_user_ids) AS granted_users(granted_user_id)
          WHERE NOT (granted_user_id = ANY(owner_acl.allowed_user_ids))
          ORDER BY granted_user_id
        ),
        updated_at = CURRENT_TIMESTAMP
      FROM access_control_lists AS owner_acl
      WHERE permission_acl.target_type = 'Boards::Board'
        AND owner_acl.target_type = permission_acl.target_type
        AND owner_acl.target_id = permission_acl.target_id
        AND owner_acl.permission = 'owner'
        AND permission_acl.permission <> 'owner'
        AND permission_acl.allowed_user_ids && owner_acl.allowed_user_ids
    SQL
  end
end
