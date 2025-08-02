# frozen_string_literal: true

class AddIndexTopicIdCreatedAtOnPosts < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    remove_index :posts, %i[topic_id created_at], algorithm: :concurrently, if_exists: true
    add_index :posts, %i[topic_id created_at], algorithm: :concurrently
  end

  def down
    remove_index :posts, %i[topic_id created_at], algorithm: :concurrently, if_exists: true
  end
end
