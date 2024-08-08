# frozen_string_literal: true

class AddCanModerateToCategoryGroups < ActiveRecord::Migration[7.1]
  def up
    add_column :category_groups, :can_moderate, :boolean, default: false, null: false

    execute <<~SQL
      UPDATE category_groups
      SET can_moderate = TRUE
      FROM categories
      WHERE category_groups.category_id = categories.id AND category_groups.group_id = categories.reviewable_by_group_id
        AND categories.reviewable_by_group_id IS NOT NULL
    SQL

    execute <<~SQL
      INSERT INTO category_groups (category_id, group_id, created_at, updated_at, permission_type, can_moderate)
      SELECT id, reviewable_by_group_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 3, TRUE
      FROM categories
      WHERE reviewable_by_group_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM category_groups
          WHERE category_groups.category_id = categories.id
            AND category_groups.group_id = categories.reviewable_by_group_id
        )
    SQL
  end

  def down
    remove_column :category_groups, :can_moderate
  end
end
