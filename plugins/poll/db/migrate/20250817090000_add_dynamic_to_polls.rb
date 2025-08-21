# frozen_string_literal: true

class AddDynamicToPolls < ActiveRecord::Migration[7.0]
  def up
    add_column :polls, :dynamic, :boolean, default: false, null: false
  end

  def down
    remove_column :polls, :dynamic
  end
end
