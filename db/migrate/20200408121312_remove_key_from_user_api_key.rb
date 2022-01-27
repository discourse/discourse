# frozen_string_literal: true

class RemoveKeyFromUserApiKey < ActiveRecord::Migration[6.0]
  DROPPED_COLUMNS ||= {
    user_api_keys: %i{key}
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
