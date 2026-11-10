# frozen_string_literal: true
class AddCoveringIndexForPostSearch < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :posts,
                 name: "idx_posts_search_covering",
                 algorithm: :concurrently,
                 if_exists: true

    add_index :posts,
              :id,
              name: "idx_posts_search_covering",
              include: %i[topic_id post_number post_type],
              where: "deleted_at IS NULL AND NOT hidden",
              algorithm: :concurrently
  end

  def down
    remove_index :posts,
                 name: "idx_posts_search_covering",
                 algorithm: :concurrently,
                 if_exists: true
  end
end
