# frozen_string_literal: true

class DropTokenFromEmailTokens < ActiveRecord::Migration[6.1]
  DROPPED_COLUMNS ||= {
    email_tokens: %i{token}
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
