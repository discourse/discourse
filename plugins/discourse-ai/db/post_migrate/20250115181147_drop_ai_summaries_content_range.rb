# frozen_string_literal: true
class DropAiSummariesContentRange < ActiveRecord::Migration[7.2]
  DROPPED_COLUMNS = { ai_summaries: %i[content_range] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
