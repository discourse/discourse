# frozen_string_literal: true

class AddIndexToAssignedToIdAndType < ActiveRecord::Migration[6.1]
  def change
    add_index :assignments, %i[assigned_to_id assigned_to_type]
  end
end
