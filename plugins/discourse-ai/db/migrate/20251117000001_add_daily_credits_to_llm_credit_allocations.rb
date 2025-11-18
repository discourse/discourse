# frozen_string_literal: true

class AddDailyCreditsToLlmCreditAllocations < ActiveRecord::Migration[8.0]
  def up
    return if column_exists?(:llm_credit_allocations, :daily_credits)

    add_column :llm_credit_allocations, :daily_credits, :bigint, null: false, default: 0

    execute <<~SQL
      UPDATE llm_credit_allocations
      SET daily_credits = GREATEST(COALESCE(monthly_credits / 30, 0), 0)
    SQL
  end

  def down
    if column_exists?(:llm_credit_allocations, :daily_credits)
      remove_column :llm_credit_allocations, :daily_credits
    end
  end
end
