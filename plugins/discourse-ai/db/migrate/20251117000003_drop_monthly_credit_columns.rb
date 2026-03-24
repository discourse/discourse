# frozen_string_literal: true

class DropMonthlyCreditColumns < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { llm_credit_allocations: %i[monthly_credits monthly_usage] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
