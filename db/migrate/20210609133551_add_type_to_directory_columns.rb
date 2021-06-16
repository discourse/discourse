# frozen_string_literal: true

class AddTypeToDirectoryColumns < ActiveRecord::Migration[6.1]
  def up
    add_column :directory_columns, :type, :integer, default: 0, null: false

    DB.exec(
      <<~SQL
        UPDATE directory_columns
        SET type = CASE WHEN automatic THEN 0 ELSE 1 END;
      SQL
    )
  end

  def down
    remove_column :directory_columns, :type, :integer, default: 0, null: false
  end
end
