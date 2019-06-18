# frozen_string_literal: true

class AddScoreToTopics < ActiveRecord::Migration[4.2]
  def change
    add_column :topics, :score, :float
    add_column :topics, :percent_rank, :float, null: false, default: 1.0
  end
end
