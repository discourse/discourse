# frozen_string_literal: true

class AddUserCountToGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :user_count, :integer, null: false, default: 0
  end
end
