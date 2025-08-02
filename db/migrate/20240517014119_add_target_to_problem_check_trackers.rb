# frozen_string_literal: true

class AddTargetToProblemCheckTrackers < ActiveRecord::Migration[7.0]
  def change
    add_column :problem_check_trackers, :target, :string, null: true
  end
end
