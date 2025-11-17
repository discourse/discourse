# frozen_string_literal: true

class AddDailyUsageToLlmCreditAllocations < ActiveRecord::Migration[8.0]
  def up
    return if column_exists?(:llm_credit_allocations, :daily_usage)

    add_column :llm_credit_allocations, :daily_usage, :jsonb, default: {}, null: false

    # Migrate existing monthly_usage data to daily_usage
    # For past months: assign to last day of that month
    # For current month: assign to current date (to avoid future dates)
    # This preserves historical totals while transitioning to daily tracking
    execute <<~SQL
      UPDATE llm_credit_allocations
      SET daily_usage = (
        SELECT jsonb_object_agg(
          CASE
            WHEN (month_date || '-01')::date >= date_trunc('month', CURRENT_TIMESTAMP)::date
            THEN to_char(CURRENT_DATE, 'YYYY-MM-DD')
            ELSE to_char((month_date || '-01')::date + interval '1 month' - interval '1 day', 'YYYY-MM-DD')
          END,
          month_usage::integer
        )
        FROM jsonb_each_text(monthly_usage) AS t(month_date, month_usage)
        WHERE month_usage::integer > 0
      )
      WHERE monthly_usage IS NOT NULL
        AND monthly_usage != '{}'::jsonb
    SQL
  end

  def down
    if column_exists?(:llm_credit_allocations, :daily_usage)
      remove_column :llm_credit_allocations, :daily_usage
    end
  end
end
