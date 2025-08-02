# frozen_string_literal: true

require "migration/column_dropper"

class DropEmailUserOptionsColumns < ActiveRecord::Migration[5.2]
  DROPPED_COLUMNS = { user_options: %i[email_direct email_private_messages email_always] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
