# frozen_string_literal: true

class AddActiveToAssignments < ActiveRecord::Migration[6.1]
  def change
    add_column :assignments, :active, :boolean, default: true
    add_index :assignments, :active
  end
end
