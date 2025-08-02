# frozen_string_literal: true

class AddTopicSlowModeInterval < ActiveRecord::Migration[6.0]
  def change
    add_column :topics, :slow_mode_seconds, :integer, null: false, default: 0
  end
end
