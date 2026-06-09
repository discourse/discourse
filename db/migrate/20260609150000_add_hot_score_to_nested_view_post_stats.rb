# frozen_string_literal: true

class AddHotScoreToNestedViewPostStats < ActiveRecord::Migration[8.0]
  def change
    add_column :nested_view_post_stats,
               :hot_score,
               :float,
               default: 0.0,
               null: false,
               if_not_exists: true
    add_column :nested_view_post_stats, :hot_score_updated_at, :datetime, if_not_exists: true
    add_column :nested_view_post_stats, :topic_id, :bigint, if_not_exists: true
    add_column :nested_view_post_stats, :reply_to_post_number, :integer, if_not_exists: true
    add_column :nested_view_post_stats, :post_number, :integer, if_not_exists: true

    add_index :nested_view_post_stats,
              %i[topic_id reply_to_post_number hot_score post_number],
              name: "idx_nested_stats_hot_siblings",
              order: {
                hot_score: :desc,
                post_number: :asc,
              },
              if_not_exists: true
  end
end
