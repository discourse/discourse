class AddPostCountToCategories < ActiveRecord::Migration[4.2]
  def up
    add_column :categories, :post_count, :integer, null: false, default: 0
    execute <<SQL
    UPDATE categories
    SET post_count = (SELECT COALESCE(SUM(posts_count),0) FROM topics
                      WHERE category_id = categories.id AND deleted_at IS NULL)
SQL
  end

  def down
    remove_column :categories, :post_count
  end
end
