class AddDeletedPostIndexToPosts < ActiveRecord::Migration[4.2]
  def change
    add_index :posts, [:topic_id, :post_number], where: 'deleted_at IS NOT NULL', name: 'idx_posts_deleted_posts'
  end
end
