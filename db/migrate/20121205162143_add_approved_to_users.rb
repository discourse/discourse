# frozen_string_literal: true

class AddApprovedToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :approved, :boolean, null: false, default: false
    add_column :users, :approved_by_id, :integer, null: true
    add_column :users, :approved_at, :timestamp, null: true
  end
end
