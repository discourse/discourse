# frozen_string_literal: true

class AddDefaultToActive < ActiveRecord::Migration[4.2]
  def change
    change_column :users, :active, :boolean, default: false, null: false
  end
end
