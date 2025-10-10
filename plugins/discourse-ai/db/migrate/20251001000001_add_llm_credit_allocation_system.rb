# frozen_string_literal: true

class AddLlmCreditAllocationSystem < ActiveRecord::Migration[7.2]
  def change
    create_table :llm_credit_allocations do |t|
      t.bigint :llm_model_id, null: false
      t.bigint :monthly_credits, null: false
      t.bigint :monthly_used, null: false, default: 0
      t.datetime :last_reset_at, null: false
      t.integer :soft_limit_percentage, null: false, default: 80
      t.timestamps
    end

    add_index :llm_credit_allocations, :llm_model_id, unique: true

    create_table :llm_feature_credit_costs do |t|
      t.bigint :llm_model_id, null: false
      t.string :feature_name, null: false
      t.decimal :credits_per_token, precision: 10, scale: 4, null: false, default: 1.0
      t.timestamps
    end

    add_index :llm_feature_credit_costs, :llm_model_id
    add_index :llm_feature_credit_costs, %i[llm_model_id feature_name], unique: true
  end
end
