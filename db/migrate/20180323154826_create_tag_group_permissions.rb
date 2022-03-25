# frozen_string_literal: true

class CreateTagGroupPermissions < ActiveRecord::Migration[5.1]
  def change
    create_table :tag_group_permissions do |t|
      t.bigint :tag_group_id, null: false
      t.bigint :group_id, null: false
      t.integer :permission_type, default: 1, null: false
      t.timestamps null: false
    end

    add_index :tag_group_permissions, :tag_group_id
    add_index :tag_group_permissions, :group_id
  end
end
