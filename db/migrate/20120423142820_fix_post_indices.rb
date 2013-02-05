class FixPostIndices < ActiveRecord::Migration
  def up
    remove_index :posts, [:forum_thread_id, :created_at]
    add_index :posts, [:forum_thread_id, :post_number]
  end

  def down
    remove_index :posts, [:forum_thread_id, :post_number]
    add_index :posts, [:forum_thread_id, :created_at]
  end
end
