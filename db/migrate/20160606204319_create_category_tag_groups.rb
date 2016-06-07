class CreateCategoryTagGroups < ActiveRecord::Migration
  def change
    create_table :category_tag_groups do |t|
      t.references :category,  null: false
      t.references :tag_group, null: false
      t.timestamps
    end

    add_index :category_tag_groups, [:category_id, :tag_group_id], name: "idx_category_tag_groups_ix1", unique: true
  end
end
