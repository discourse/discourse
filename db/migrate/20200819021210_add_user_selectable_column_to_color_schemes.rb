# frozen_string_literal: true

class AddUserSelectableColumnToColorSchemes < ActiveRecord::Migration[6.0]
  def change
    add_column :color_schemes, :user_selectable, :bool, null: false, default: false
  end
end
