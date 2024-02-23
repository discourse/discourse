# frozen_string_literal: true

class CreateProblemCheckTrackers < ActiveRecord::Migration[7.0]
  def change
    create_table :problem_check_trackers do |t|
      t.string :identifier, null: false, index: { unique: true }

      t.integer :blips, null: false, default: 0

      t.datetime :last_run_at
      t.datetime :next_run_at
      t.datetime :last_success_at
      t.datetime :last_problem_at
    end
  end
end
