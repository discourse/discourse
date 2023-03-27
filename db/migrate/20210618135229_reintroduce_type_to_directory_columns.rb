# frozen_string_literal: true

class ReintroduceTypeToDirectoryColumns < ActiveRecord::Migration[6.1]
  def up
    if !ActiveRecord::Base.connection.column_exists?(:directory_columns, :type)
      # A migration that added this column was previously merged and reverted.
      # Some sites have this column and some do not, so only add if missing.
      add_column :directory_columns, :type, :integer, default: 0, null: false
    end

    DB.exec(<<~SQL)
        UPDATE directory_columns
        SET type = CASE WHEN automatic THEN 0 ELSE 1 END;
      SQL
  end

  def down
    remove_column :directory_columns, :type
  end
end
