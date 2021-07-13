# frozen_string_literal: true

class AddDefaultAutoCloseSecondsToCategory < ActiveRecord::Migration[6.1]
  def change
    add_column :categories, :default_slow_mode_seconds, :integer
  end
end
