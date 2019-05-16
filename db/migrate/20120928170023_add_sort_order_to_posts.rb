# frozen_string_literal: true

class AddSortOrderToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :sort_order, :integer
    remove_index :posts, :user_id
    execute "UPDATE posts AS p SET sort_order = post_number FROM forum_threads AS ft WHERE ft.id = p.forum_thread_id AND ft.archetype_id = 1"
  end
end
