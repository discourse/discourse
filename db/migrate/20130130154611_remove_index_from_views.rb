# frozen_string_literal: true

class RemoveIndexFromViews < ActiveRecord::Migration[4.2]
  def up
    remove_index "views", name: "unique_views"
    change_column :views, :viewed_at, :date
  end

  def down
    add_index "views", ["parent_id", "parent_type", "ip", "viewed_at"], name: "unique_views", unique: true
    change_column :views, :viewed_at, :timestamp
  end
end
