# frozen_string_literal: true

class RecreateSolutionsColumn < ActiveRecord::Migration[6.1]
  def up
    if !ActiveRecord::Base.connection.column_exists?(:directory_items, :solutions)
      # A reverted commit had added this column previously so some sites have this
      # column, and some so not. Only add if the DB doesn't already have it.
      add_column :directory_items, :solutions, :integer, default: 0
    end
  end

  def down
    remove_column :directory_items, :solutions
  end
end
