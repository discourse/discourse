# frozen_string_literal: true

class CreateCategoryApprovalGroups < ActiveRecord::Migration[8.0]
  def up
    create_table :category_posting_review_groups do |t|
      t.integer :post_type, null: false
      t.integer :permission, null: false
      t.integer :category_id, null: false
      t.integer :group_id, null: false
      t.timestamps null: false
    end

    add_index :category_posting_review_groups,
              %i[category_id group_id post_type],
              unique: true,
              name: "idx_category_posting_review_groups_unique"

    # Backfill: for each category with require_topic_approval = true,
    # insert a "required" row for the everyone group (id 0) with post_type topic (0).
    execute(<<~SQL)
      INSERT INTO category_posting_review_groups (post_type, permission, category_id, group_id, created_at, updated_at)
      SELECT 0, 1, cs.category_id, 0, NOW(), NOW()
      FROM category_settings cs
      WHERE cs.require_topic_approval = true
    SQL

    # Same for reply approval: post_type reply (1).
    execute(<<~SQL)
      INSERT INTO category_posting_review_groups (post_type, permission, category_id, group_id, created_at, updated_at)
      SELECT 1, 1, cs.category_id, 0, NOW(), NOW()
      FROM category_settings cs
      WHERE cs.require_reply_approval = true
    SQL
  end

  def down
    drop_table :category_posting_review_groups
  end
end
