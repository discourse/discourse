# frozen_string_literal: true

class AddStatusToAssignments < ActiveRecord::Migration[6.1]
  def change
    add_column :assignments, :status, :text, null: true
  end
end
