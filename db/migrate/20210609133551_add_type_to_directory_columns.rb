# frozen_string_literal: true

class AddTypeToDirectoryColumns < ActiveRecord::Migration[6.1]
  def up
    add_column :directory_columns, :type, :integer, default: 0, null: false

    DB.exec(
      <<~SQL
        UPDATE directory_columns
        SET type = 0
        WHERE automatic = true;

        UPDATE directory_columns
        SET type = 1
        WHERE automatic = false;
      SQL
    )
  end

  def down
    remove_column :directory_columns, :type, :integer, default: 0, null: false
  end
end
