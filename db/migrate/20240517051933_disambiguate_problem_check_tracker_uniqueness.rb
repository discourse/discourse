# frozen_string_literal: true

class DisambiguateProblemCheckTrackerUniqueness < ActiveRecord::Migration[7.0]
  def change
    remove_index :problem_check_trackers, name: "index_problem_check_trackers_on_identifier"
    add_index :problem_check_trackers, %i[identifier target], unique: true
  end
end
