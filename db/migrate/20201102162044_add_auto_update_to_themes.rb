# frozen_string_literal: true

class AddAutoUpdateToThemes < ActiveRecord::Migration[6.0]
  def change
    add_column :themes, :auto_update, :boolean, null: false, default: true
  end
end
