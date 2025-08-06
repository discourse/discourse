# frozen_string_literal: true

class CreateAssignments < ActiveRecord::Migration[6.1]
  def change
    create_table :assignments do |t|
      t.integer :topic_id, null: false
      t.integer :assigned_to_id, null: false
      t.integer :assigned_by_user_id, null: false

      t.timestamps
    end

    add_index :assignments, :topic_id, unique: true
  end
end
