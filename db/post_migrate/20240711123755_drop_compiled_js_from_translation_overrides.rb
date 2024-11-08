# frozen_string_literal: true

class DropCompiledJsFromTranslationOverrides < ActiveRecord::Migration[7.1]
  DROPPED_COLUMNS = { translation_overrides: %i[compiled_js] }.freeze

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
