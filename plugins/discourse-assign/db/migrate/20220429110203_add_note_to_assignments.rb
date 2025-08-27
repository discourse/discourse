# frozen_string_literal: true

class AddNoteToAssignments < ActiveRecord::Migration[6.1]
  def change
    add_column :assignments, :note, :string, null: true
  end
end
