# frozen_string_literal: true

class AddMembersVisibilityLevelToGroups < ActiveRecord::Migration[5.2]
  def change
    add_column :groups, :members_visibility_level, :integer, default: 0, null: false
  end
end
