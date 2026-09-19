# frozen_string_literal: true

class AddClosedByToPolls < ActiveRecord::Migration[8.0]
  def change
    add_column :polls, :closed_by_id, :integer, null: true
    add_column :polls, :closed_at, :datetime, null: true
  end
end
