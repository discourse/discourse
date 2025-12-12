# frozen_string_literal: true

class DropDailyUsageFromLlmCreditAllocations < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { llm_credit_allocations: %i[daily_usage] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
