# frozen_string_literal: true

class DecisionModelFeatureCreditCost < ActiveRecord::Base
  belongs_to :decision_model

  validates :decision_model_id, presence: true
  validates :feature_name, presence: true, uniqueness: { scope: :decision_model_id }
  validates :credits_per_token, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def self.credit_cost_for(decision_model, feature_name)
    costs =
      where(decision_model:, feature_name: [feature_name, "default"]).pluck(
        :feature_name,
        :credits_per_token,
      ).to_h
    (costs[feature_name] || costs["default"] || 1.0).to_f
  end

  def self.calculate_credit_cost(decision_model, feature_name, tokens)
    (tokens * credit_cost_for(decision_model, feature_name)).ceil
  end
end

# == Schema Information
#
# Table name: decision_model_feature_credit_costs
#
#  id                :bigint           not null, primary key
#  credits_per_token :decimal(10, 4)   default(1.0), not null
#  feature_name      :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  decision_model_id :bigint           not null
#
# Indexes
#
#  index_decision_model_feature_credit_costs_on_model_and_feature  (decision_model_id,feature_name) UNIQUE
#
