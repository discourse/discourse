# frozen_string_literal: true
class IntroducePermissionAclTables < ActiveRecord::Migration[8.0]
  def change
    create_table :access_control_lists do |t|
      t.string :target_type, null: false
      t.bigint :target_id, null: false

      t.string :owner, null: false
      t.string :permission, null: false

      t.bigint :allowed_user_ids, array: true, null: false, default: []
      t.bigint :allowed_group_ids, array: true, null: false, default: []

      t.timestamps
    end

    add_index :access_control_lists, %i[target_type target_id], unique: true
    execute "CREATE INDEX idx_access_control_lists_allowed_user_ids ON access_control_lists USING GIN(allowed_user_ids)"
    execute "CREATE INDEX idx_access_control_lists_allowed_group_ids ON access_control_lists USING GIN(allowed_group_ids)"
  end
end
