# frozen_string_literal: true

class DropUploadsVerified < ActiveRecord::Migration[6.1]
  DROPPED_COLUMNS = { uploads: %i[verified] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    add_column :uploads, :verified, :string
  end
end
