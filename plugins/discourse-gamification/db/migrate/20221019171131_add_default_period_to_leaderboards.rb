# frozen_string_literal: true
class AddDefaultPeriodToLeaderboards < ActiveRecord::Migration[6.1]
  def up
    add_column :gamification_leaderboards, :default_period, :integer, default: 0
  end

  def down
    remove_column :gamification_leaderboards, :default_period
  end
end
