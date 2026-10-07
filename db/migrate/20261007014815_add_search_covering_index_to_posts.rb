# frozen_string_literal: true

class AddSearchCoveringIndexToPosts < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :posts,
                 name: "index_posts_on_id_for_search",
                 algorithm: :concurrently,
                 if_exists: true

    add_index :posts,
              :id,
              name: "index_posts_on_id_for_search",
              include: %i[topic_id post_number post_type user_id created_at like_count],
              where: "deleted_at IS NULL AND NOT hidden",
              algorithm: :concurrently
  end

  def down
    remove_index :posts,
                 name: "index_posts_on_id_for_search",
                 algorithm: :concurrently,
                 if_exists: true
  end
end
