# frozen_string_literal: true
class RefactorLlmCreditAllocationToMonthlyUsage < ActiveRecord::Migration[8.0]
  def up
    add_column :llm_credit_allocations, :monthly_usage, :jsonb, default: {}, null: false

    execute <<~SQL
      UPDATE llm_credit_allocations
      SET monthly_usage = jsonb_build_object(
        to_char(COALESCE(last_reset_at, CURRENT_TIMESTAMP), 'YYYY-MM'),
        monthly_used
      )
      WHERE monthly_used > 0
    SQL

    remove_column :llm_credit_allocations, :monthly_used
    remove_column :llm_credit_allocations, :last_reset_at
  end

  def down
    add_column :llm_credit_allocations, :monthly_used, :bigint, default: 0, null: false
    add_column :llm_credit_allocations,
               :last_reset_at,
               :datetime,
               null: false,
               default: -> { "date_trunc('month', CURRENT_TIMESTAMP)" }

    execute <<~SQL
      UPDATE llm_credit_allocations
      SET monthly_used = COALESCE(
        (monthly_usage->>to_char(CURRENT_TIMESTAMP, 'YYYY-MM'))::bigint,
        0
      ),
      last_reset_at = date_trunc('month', CURRENT_TIMESTAMP)
    SQL

    remove_column :llm_credit_allocations, :monthly_usage
  end
end
