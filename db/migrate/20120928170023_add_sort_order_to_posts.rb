class AddSortOrderToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :sort_order, :integer
    remove_index :posts, :user_id
    execute "UPDATE posts AS p SET sort_order = post_number FROM forum_threads AS ft WHERE ft.id = p.forum_thread_id AND ft.archetype_id = 1"
    execute "UPDATE posts AS p SET sort_order =
                CASE WHEN post_number = 1 THEN 1
                     ELSE 2147483647 - p.vote_count
                END
             FROM forum_threads AS ft
             WHERE ft.id = p.forum_thread_id AND ft.archetype_id = 2"
  end
end
