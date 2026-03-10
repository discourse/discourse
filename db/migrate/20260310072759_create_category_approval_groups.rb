# frozen_string_literal: true

class CreateCategoryApprovalGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :category_approval_groups do |t|
      t.integer :category_id, null: false
      t.integer :group_id, null: false
      t.string :approval_type, null: false
      t.timestamps null: false
    end

    add_index :category_approval_groups,
              %i[category_id group_id approval_type],
              unique: true,
              name: "idx_category_approval_groups_unique"
  end
end
