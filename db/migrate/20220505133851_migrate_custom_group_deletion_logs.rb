# frozen_string_literal: true
class MigrateCustomGroupDeletionLogs < ActiveRecord::Migration[7.0]
  def up
    DB.exec(<<~SQL, group_deleted_id: 99, custom_action_id: 23)
      UPDATE user_histories
      SET action = :group_deleted_id, custom_type = NULL
      WHERE action = :custom_action_id AND custom_type = 'delete_group'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
