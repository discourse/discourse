# frozen_string_literal: true
class AddIgnoredAtToProblemCheckTrackers < ActiveRecord::Migration[8.0]
  def change
    add_column :problem_check_trackers, :ignored_at, :datetime
  end
end
