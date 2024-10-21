# frozen_string_literal: true

class SwapFieldTypeWithFieldTypeEnumOnUserFields < ActiveRecord::Migration[7.0]
  # DROPPED_COLUMNS = { user_fields: %i[field_type] }

  # def up
  #   # WARNING: Swapping in a column of a different type in a post-migration will break the AR
  #   #          cache, since the application is already booted, requiring a restart.
  #   #
  #   DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  #   rename_column :user_fields, :field_type_enum, :field_type
  # end

  # def down
  #   raise ActiveRecord::IrreversibleMigration
  # end
end
