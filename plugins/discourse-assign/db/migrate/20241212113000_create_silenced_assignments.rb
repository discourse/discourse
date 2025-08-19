# frozen_string_literal: true
class CreateSilencedAssignments < ActiveRecord::Migration[7.2]
  def up
    create_table :silenced_assignments do |t|
      t.bigint :assignment_id, null: false
      t.timestamps
    end
    add_index :silenced_assignments, :assignment_id, unique: true
  end

  def down
    drop_table :silenced_assignments
  end
end
