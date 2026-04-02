# frozen_string_literal: true

class AddScoreOverridesToGamificationLeaderboards < ActiveRecord::Migration[7.2]
  def change
    add_column :gamification_leaderboards, :score_overrides, :jsonb, default: nil
    add_column :gamification_leaderboards,
               :scorable_category_ids,
               :integer,
               array: true,
               default: nil
  end
end
