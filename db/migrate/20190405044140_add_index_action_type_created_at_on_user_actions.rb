# frozen_string_literal: true

class AddIndexActionTypeCreatedAtOnUserActions < ActiveRecord::Migration[5.2]
  def change
    add_index :user_actions, [:action_type, :created_at]
  end
end
