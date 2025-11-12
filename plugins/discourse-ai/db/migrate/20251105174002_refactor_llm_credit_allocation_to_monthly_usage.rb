# frozen_string_literal: true

class RefactorLlmCreditAllocationToMonthlyUsage < ActiveRecord::Migration[8.0]
  def up
    return if column_exists?(:llm_credit_allocations, :monthly_usage)

    add_column :llm_credit_allocations, :monthly_usage, :jsonb, default: {}, null: false

    execute <<~SQL
      UPDATE llm_credit_allocations
      SET monthly_usage = jsonb_build_object(
        to_char(COALESCE(last_reset_at, CURRENT_TIMESTAMP), 'YYYY-MM'),
        monthly_used
      )
      WHERE monthly_used > 0
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
