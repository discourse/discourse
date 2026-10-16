# frozen_string_literal: true
class CreateDecisionModelCredits < ActiveRecord::Migration[8.1]
  def change
    create_table :decision_model_credit_allocations do |t|
      t.bigint :decision_model_id, null: false
      t.bigint :daily_credits, null: false
      t.integer :soft_limit_percentage, null: false, default: 80
      t.timestamps
    end
    add_index :decision_model_credit_allocations, :decision_model_id, unique: true

    create_table :decision_model_credit_daily_usages do |t|
      t.bigint :decision_model_id, null: false
      t.date :usage_date, null: false
      t.bigint :credits_used, null: false, default: 0
      t.timestamps
    end
    add_index :decision_model_credit_daily_usages, %i[decision_model_id usage_date], unique: true

    create_table :decision_model_feature_credit_costs do |t|
      t.bigint :decision_model_id, null: false
      t.string :feature_name, null: false
      t.decimal :credits_per_token, precision: 10, scale: 4, null: false, default: 1.0
      t.timestamps
    end
    add_index :decision_model_feature_credit_costs,
              %i[decision_model_id feature_name],
              unique: true,
              name: "index_decision_model_feature_credit_costs_on_model_and_feature"
  end
end
