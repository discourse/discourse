# frozen_string_literal: true
class AddExcludedGroupsToLeaderboards < ActiveRecord::Migration[6.1]
  def change
    add_column :gamification_leaderboards,
               :excluded_groups_ids,
               :integer,
               array: true,
               null: false,
               default: []
  end
end
