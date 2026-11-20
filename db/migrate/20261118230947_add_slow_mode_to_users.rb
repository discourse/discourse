# frozen_string_literal: true

class AddSlowModeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users,
               :user_slow_mode_seconds,
               :integer,
               default: 0,
               null: false,
               if_not_exists: true
    add_column :users, :user_slow_mode_until, :datetime, if_not_exists: true
  end
end
