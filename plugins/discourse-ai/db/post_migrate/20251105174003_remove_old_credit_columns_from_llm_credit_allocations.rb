# frozen_string_literal: true

class RemoveOldCreditColumnsFromLlmCreditAllocations < ActiveRecord::Migration[8.0]
  def up
    if column_exists?(:llm_credit_allocations, :monthly_used)
      remove_column :llm_credit_allocations, :monthly_used
    end

    if column_exists?(:llm_credit_allocations, :last_reset_at)
      remove_column :llm_credit_allocations, :last_reset_at
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
