# frozen_string_literal: true

class ChangeAutomaticOnDirectoryColumnsToBool < ActiveRecord::Migration[6.1]
  def up
    begin
      Migration::SafeMigrate.disable!

      # Because of a weird state we are in where some sites have a boolean type column for `automatic` and some
      # have an `integer`type, we remove the column. Then we re-create it and using `user_field_id` to determine
      # if the value should be true or false.
      remove_column :directory_columns, :automatic
      add_column :directory_columns, :automatic, :boolean, default: true, null: false

      execute <<~SQL
        UPDATE directory_columns SET automatic = (user_field_id IS NULL);
      SQL
    ensure
      Migration::SafeMigrate.enable!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
