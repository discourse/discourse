# frozen_string_literal: true

class AddAutomaticColumnDirectoryColumns < ActiveRecord::Migration[6.1]
  def up
    if !ActiveRecord::Base.connection.column_exists?(:directory_columns, :automatic)
      add_column :directory_columns, :automatic, :integer, default: true
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
