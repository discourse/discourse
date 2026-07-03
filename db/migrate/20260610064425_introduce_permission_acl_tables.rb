# frozen_string_literal: true
class IntroducePermissionAclTables < ActiveRecord::Migration[8.0]
  def up
    create_table :access_control_lists do |t|
      t.string :target_type, null: false, limit: 255
      t.bigint :target_id, null: false

      t.string :owner, null: false, limit: 100
      t.string :permission, null: false, limit: 100

      t.bigint :allowed_user_ids, array: true, null: false, default: []
      t.bigint :allowed_group_ids, array: true, null: false, default: []

      t.timestamps
    end

    add_index :access_control_lists, %i[target_type target_id permission], unique: true
    execute "CREATE INDEX idx_access_control_lists_allowed_user_ids ON access_control_lists USING GIN(allowed_user_ids)"
    execute "CREATE INDEX idx_access_control_lists_allowed_group_ids ON access_control_lists USING GIN(allowed_group_ids)"
  end

  def down
    drop_table :access_control_lists

    if index_exists?(:access_control_lists, :allowed_user_ids, using: :gin)
      execute "DROP INDEX idx_access_control_lists_allowed_user_ids"
    end
    if index_exists?(:access_control_lists, :allowed_group_ids, using: :gin)
      execute "DROP INDEX idx_access_control_lists_allowed_group_ids"
    end
    if index_exists?(:access_control_lists, %i[target_type target_id permission], unique: true)
      remove_index :access_control_lists, column: %i[target_type target_id permission]
    end
  end
end
