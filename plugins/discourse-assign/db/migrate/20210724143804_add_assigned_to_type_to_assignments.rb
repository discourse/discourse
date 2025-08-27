# frozen_string_literal: true

class AddAssignedToTypeToAssignments < ActiveRecord::Migration[6.1]
  def up
    add_column :assignments, :assigned_to_type, :string

    execute <<~SQL
      UPDATE assignments
      SET assigned_to_type = 'User'
      WHERE assigned_to_type IS NULL
    SQL

    change_column :assignments, :assigned_to_type, :string, null: false
  end

  def down
    remove_column :assignments, :assigned_to_type
  end
end
