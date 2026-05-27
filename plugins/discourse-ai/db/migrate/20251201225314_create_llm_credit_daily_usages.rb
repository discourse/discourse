# frozen_string_literal: true
class CreateLlmCreditDailyUsages < ActiveRecord::Migration[8.0]
  def change
    create_table :llm_credit_daily_usages do |t|
      t.bigint :llm_model_id, null: false
      t.date :usage_date, null: false
      t.bigint :credits_used, null: false, default: 0
      t.timestamps
    end

    add_index :llm_credit_daily_usages, :llm_model_id
    add_index :llm_credit_daily_usages, %i[llm_model_id usage_date], unique: true
  end
end
