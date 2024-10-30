# frozen_string_literal: true
class RemoveNullsNotDistinctFromProblemCheckTrackers < ActiveRecord::Migration[7.1]
  def up
    remove_index :problem_check_trackers, %i[identifier target], if_exists: true
    add_index :problem_check_trackers, %i[identifier target], unique: true
  end

  def down
    remove_index :problem_check_trackers, %i[identifier target], if_exists: true
    add_index :problem_check_trackers, %i[identifier target], unique: true, nulls_not_distinct: true
  end
end
