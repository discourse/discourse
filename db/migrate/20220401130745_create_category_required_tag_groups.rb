# frozen_string_literal: true

class CreateCategoryRequiredTagGroups < ActiveRecord::Migration[6.1]
  def up
    create_table :category_required_tag_groups do |t|
      t.bigint :category_id, null: false
      t.bigint :tag_group_id, null: false
      t.integer :min_count, null: false, default: 1
      t.integer :order, null: false, default: 1
      t.timestamps
    end

    add_index :category_required_tag_groups,
              %i[category_id tag_group_id],
              name: "idx_category_required_tag_groups",
              unique: true

    execute <<~SQL
      INSERT INTO category_required_tag_groups
      (category_id, tag_group_id, min_count, updated_at, created_at)
      SELECT c.id, c.required_tag_group_id, c.min_tags_from_required_group, NOW(), NOW()
      FROM categories c
      INNER JOIN tag_groups tg ON tg.id = c.required_tag_group_id
      WHERE tg.id IS NOT NULL
    SQL
  end

  def down
    drop_table :category_required_tag_groups
  end
end
