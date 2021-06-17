# frozen_string_literal: true

class AddAutomaticColumnDirectoryColumns < ActiveRecord::Migration[6.1]
  def up
    if ActiveRecord::Base.connection.column_exists?(:directory_columns, :type)
      # This database ran 20210609133551_add_type_to_directory_columns
      # and post_migrate/20210609152431_remove_directory_column_automatic
      # These have been reverted, so we need to clean up

      change_column_default :directory_items, :automatic, nil
      change_column_null :directory_items, :automatic, false

      execute <<~SQL
        UPDATE directory_columns SET automatic = (type = 0);
      SQL

      remove_column :directory_columns, :type
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
