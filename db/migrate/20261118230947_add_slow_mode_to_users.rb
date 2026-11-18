# frozen_string_literal: true

class AddSlowModeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :user_slow_mode_seconds, :integer, default: 0, null: false
    add_column :users, :user_slow_mode_until, :datetime
  end
end
