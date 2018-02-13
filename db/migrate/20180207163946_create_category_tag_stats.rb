class CreateCategoryTagStats < ActiveRecord::Migration[5.1]
  def change
    create_table :category_tag_stats do |t|
      t.references :category, null: false
      t.references :tag, null: false
      t.integer :topic_count, default: 0, null: false
    end

    add_index :category_tag_stats, [:category_id, :topic_count]
    add_index :category_tag_stats, [:category_id, :tag_id], unique: true
  end
end
