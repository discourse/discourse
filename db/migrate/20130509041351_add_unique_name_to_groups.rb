# frozen_string_literal: true

class AddUniqueNameToGroups < ActiveRecord::Migration[4.2]
  def change
    add_index :groups, [:name], unique: true
  end
end
