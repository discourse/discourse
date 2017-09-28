class RemoveCategoryGroupsOrphanedByRemovingCategoryOrGroup < ActiveRecord::Migration[4.2]
  def up
    execute "DELETE FROM category_groups
             WHERE group_id NOT IN (
                 SELECT groups.id FROM groups)
              OR category_id NOT IN (
                 SELECT categories.id FROM categories)"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
