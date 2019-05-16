# frozen_string_literal: true

class CreateCategoryTags < ActiveRecord::Migration[4.2]
  def change
    create_table :category_tags do |t|
      t.references :category, null: false
      t.references :tag,      null: false
      t.timestamps null: false
    end

    add_index :category_tags, [:category_id, :tag_id], name: "idx_category_tags_ix1", unique: true
    add_index :category_tags, [:tag_id, :category_id], name: "idx_category_tags_ix2", unique: true
  end
end
