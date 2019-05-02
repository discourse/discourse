# frozen_string_literal: true

class FixPostIndices < ActiveRecord::Migration[4.2]
  def up
    remove_index :posts, [:forum_thread_id, :created_at]
    add_index :posts, [:forum_thread_id, :post_number]
  end

  def down
    remove_index :posts, [:forum_thread_id, :post_number]
    add_index :posts, [:forum_thread_id, :created_at]
  end
end
