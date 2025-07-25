# frozen_string_literal: true

class AddPeriodFilterDisabledToLeaderboards < ActiveRecord::Migration[7.2]
  def change
    add_column :gamification_leaderboards,
               :period_filter_disabled,
               :boolean,
               default: false,
               null: false
  end
end
