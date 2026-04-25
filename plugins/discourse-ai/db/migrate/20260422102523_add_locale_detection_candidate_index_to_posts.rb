# frozen_string_literal: true

class AddLocaleDetectionCandidateIndexToPosts < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :posts,
                 name: "index_posts_on_updated_at_for_locale_detection",
                 algorithm: :concurrently,
                 if_exists: true
    add_index :posts,
              :updated_at,
              order: {
                updated_at: :desc,
              },
              where: "deleted_at IS NULL AND user_id > 0 AND locale IS NULL",
              name: "index_posts_on_updated_at_for_locale_detection",
              algorithm: :concurrently
  end
end
