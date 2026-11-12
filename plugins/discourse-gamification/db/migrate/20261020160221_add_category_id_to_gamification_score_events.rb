# frozen_string_literal: true
class AddCategoryIdToGamificationScoreEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :gamification_score_events, :category_id, :integer
  end
end
