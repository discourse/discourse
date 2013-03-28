class AddScoreToTopics < ActiveRecord::Migration
  def change
    add_column :topics, :score, :float
    add_column :topics, :percent_rank, :float, null: false, default: 1.0
  end
end
