# frozen_string_literal: true

class AddDetailsToProblemCheckTrackers < ActiveRecord::Migration[7.0]
  def change
    add_column :problem_check_trackers, :details, :json, default: {}
  end
end
