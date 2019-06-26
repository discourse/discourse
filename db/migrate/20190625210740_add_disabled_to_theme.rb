# frozen_string_literal: true

class AddDisabledToTheme < ActiveRecord::Migration[5.2]
  def change
    add_column :themes, :disabled, :boolean, default: false, null: false
  end
end
