# frozen_string_literal: true

class AddAssignableLevelToGroups < ActiveRecord::Migration[6.1]
  def change
    add_column :groups, :assignable_level, :integer, default: 0, null: false
  end
end
