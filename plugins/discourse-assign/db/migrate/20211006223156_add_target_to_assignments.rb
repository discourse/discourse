# frozen_string_literal: true

class AddTargetToAssignments < ActiveRecord::Migration[6.1]
  def up
    add_column :assignments, :target_id, :integer
    add_column :assignments, :target_type, :string

    execute <<~SQL
      UPDATE assignments
      SET target_type = 'Topic', target_id = topic_id
      WHERE target_type IS NULL
    SQL

    change_column :assignments, :target_id, :integer, null: false
    change_column :assignments, :target_type, :string, null: false

    add_index :assignments, %i[target_id target_type], unique: true
    add_index :assignments,
              %i[assigned_to_id assigned_to_type target_id target_type],
              unique: true,
              name: "unique_target_and_assigned"
  end

  def down
    remove_columns :assignments, :target_id, :target_type
  end
end
