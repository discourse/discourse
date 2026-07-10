# frozen_string_literal: true

class AddHotScoreToNestedViewPostStats < ActiveRecord::Migration[8.0]
  def change
    add_column :nested_view_post_stats, :hot_score, :float, default: 0.0, null: false
    add_column :nested_view_post_stats, :hot_score_updated_at, :datetime
    add_column :nested_view_post_stats, :structural_backfilled_at, :datetime
    add_column :nested_view_post_stats, :thread_hot_score, :float, default: 0.0, null: false
  end
end
