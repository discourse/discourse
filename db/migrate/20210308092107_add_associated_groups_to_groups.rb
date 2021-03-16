# frozen_string_literal: true
class AddAssociatedGroupsToGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :groups, :associated_groups, :string, null: true
  end
end
