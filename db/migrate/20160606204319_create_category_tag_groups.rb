# frozen_string_literal: true

class CreateCategoryTagGroups < ActiveRecord::Migration[4.2]
  def change
    create_table :category_tag_groups do |t|
      t.integer :category_id, null: false
      t.integer :tag_group_id, null: false
      t.timestamps null: false
    end

    add_index :category_tag_groups, [:category_id, :tag_group_id], name: "idx_category_tag_groups_ix1", unique: true
  end
end
