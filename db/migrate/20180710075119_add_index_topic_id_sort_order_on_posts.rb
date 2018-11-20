class AddIndexTopicIdSortOrderOnPosts < ActiveRecord::Migration[5.2]
  def change
    add_index :posts, [:topic_id, :sort_order], order: { sort_order: :asc }
  end
end
