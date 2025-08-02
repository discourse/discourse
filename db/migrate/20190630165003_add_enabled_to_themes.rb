# frozen_string_literal: true

class AddEnabledToThemes < ActiveRecord::Migration[5.2]
  def change
    add_column :themes, :enabled, :boolean, null: false, default: true
  end
end
