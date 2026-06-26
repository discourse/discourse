# frozen_string_literal: true

class AddRelativeHotScoresToNestedViewPostStats < ActiveRecord::Migration[8.0]
  def change
    add_column :nested_view_post_stats,
               :relative_hot_score,
               :float,
               default: 0.0,
               null: false,
               if_not_exists: true
    add_column :nested_view_post_stats,
               :relative_thread_hot_score,
               :float,
               default: 0.0,
               null: false,
               if_not_exists: true
  end
end
