# frozen_string_literal: true

class CreateCategoryModerationGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :category_moderation_groups do |t|
      t.integer :category_id
      t.integer :group_id

      t.timestamps
    end

    add_index :category_moderation_groups, %i[category_id group_id], unique: true

    execute <<~SQL
      INSERT INTO category_moderation_groups (category_id, group_id, created_at, updated_at)
      SELECT id, reviewable_by_group_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM categories
      WHERE reviewable_by_group_id IS NOT NULL
    SQL
  end
end
