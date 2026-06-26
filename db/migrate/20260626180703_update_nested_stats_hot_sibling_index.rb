# frozen_string_literal: true

class UpdateNestedStatsHotSiblingIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_nested_stats_hot_siblings"

  def up
    remove_index :nested_view_post_stats,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :nested_view_post_stats,
              %i[topic_id reply_to_post_number thread_hot_score hot_score post_number],
              name: INDEX_NAME,
              order: {
                thread_hot_score: :desc,
                hot_score: :desc,
                post_number: :asc,
              },
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :nested_view_post_stats,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :nested_view_post_stats,
              %i[topic_id reply_to_post_number hot_score post_number],
              name: INDEX_NAME,
              order: {
                hot_score: :desc,
                post_number: :asc,
              },
              algorithm: :concurrently,
              if_not_exists: true
  end
end
