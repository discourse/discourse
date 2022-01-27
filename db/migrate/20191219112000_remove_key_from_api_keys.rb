# frozen_string_literal: true
class RemoveKeyFromApiKeys < ActiveRecord::Migration[6.0]
  DROPPED_COLUMNS ||= {
    api_keys: %i{key}
  }

  def up
    DROPPED_COLUMNS.each do |table, columns|
      Migration::ColumnDropper.execute_drop(table, columns)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
