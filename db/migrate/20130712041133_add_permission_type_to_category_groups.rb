class AddPermissionTypeToCategoryGroups < ActiveRecord::Migration
  def change
    # 1 is full permissions
    add_column :category_groups, :permission_type, :integer, default: 1

    # secure is ambiguous after this change, it should be read_restricted
    rename_column :categories, :secure, :read_restricted
  end
end
