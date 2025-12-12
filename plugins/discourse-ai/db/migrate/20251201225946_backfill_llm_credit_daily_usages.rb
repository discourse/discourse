# frozen_string_literal: true
class BackfillLlmCreditDailyUsages < ActiveRecord::Migration[8.0]
  def up
    return unless column_exists?(:llm_credit_allocations, :daily_usage)

    # Migrate existing daily_usage JSONB data to the new table
    # This preserves all historical usage data
    execute <<~SQL
      INSERT INTO llm_credit_daily_usages (llm_model_id, usage_date, credits_used, created_at, updated_at)
      SELECT
        lca.llm_model_id,
        to_date(t.date_key, 'YYYY-MM-DD') as usage_date,
        t.credits::bigint as credits_used,
        NOW() as created_at,
        NOW() as updated_at
      FROM llm_credit_allocations lca,
      LATERAL jsonb_each_text(lca.daily_usage) AS t(date_key, credits)
      WHERE lca.daily_usage IS NOT NULL
        AND lca.daily_usage != '{}'::jsonb
        AND t.credits::integer > 0
      ON CONFLICT (llm_model_id, usage_date) DO UPDATE
      SET credits_used = EXCLUDED.credits_used,
          updated_at = NOW()
    SQL
  end

  def down
    # Intentionally left empty - we don't want to delete migrated data
    # The JSONB column will be removed in a separate migration
  end
end
