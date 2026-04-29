# frozen_string_literal: true

class AddLocalizationIndexesToTopics < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :topics,
                 name: "index_topics_on_updated_at_for_locale_detection",
                 algorithm: :concurrently,
                 if_exists: true
    add_index :topics,
              :updated_at,
              order: {
                updated_at: :desc,
              },
              where: "deleted_at IS NULL AND user_id > 0 AND locale IS NULL",
              name: "index_topics_on_updated_at_for_locale_detection",
              algorithm: :concurrently

    remove_index :topics,
                 name: "index_topics_on_updated_at_for_localization",
                 algorithm: :concurrently,
                 if_exists: true
    add_index :topics,
              :updated_at,
              order: {
                updated_at: :desc,
              },
              where: "deleted_at IS NULL AND user_id > 0 AND locale IS NOT NULL",
              name: "index_topics_on_updated_at_for_localization",
              algorithm: :concurrently
  end
end
