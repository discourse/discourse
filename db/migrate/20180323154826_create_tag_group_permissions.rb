class CreateTagGroupPermissions < ActiveRecord::Migration[5.1]
  def change
    create_table :tag_group_permissions do |t|
      t.references :tag_group,  null: false
      t.references :group, null: false
      t.integer :permission_type, default: 1, null: false
      t.timestamps null: false
    end
  end
end
