# frozen_string_literal: true

class AddReportsIndexToUserVisits < ActiveRecord::Migration[4.2]
  def up
    add_index :user_visits, [:visited_at, :mobile]
  end

  def down
    remove_index :user_visits, [:visited_at, :mobile]
  end
end
