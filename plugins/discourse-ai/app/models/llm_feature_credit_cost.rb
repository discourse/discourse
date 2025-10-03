# frozen_string_literal: true

class LlmFeatureCreditCost < ActiveRecord::Base
  self.table_name = "llm_feature_credit_costs"

  belongs_to :llm_model

  validates :llm_model_id, presence: true
  validates :feature_name, presence: true
  validates :credits_per_token, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :feature_name, uniqueness: { scope: :llm_model_id }

  def self.credit_cost_for(llm_model, feature_name)
    return 1.0 if llm_model.blank? || feature_name.blank?

    cost =
      where(llm_model: llm_model, feature_name: feature_name).pick(:credits_per_token) ||
        where(llm_model: llm_model, feature_name: "default").pick(:credits_per_token) || 1.0

    cost.to_f
  end

  def self.calculate_credit_cost(llm_model, feature_name, total_tokens)
    cost_per_token = credit_cost_for(llm_model, feature_name)
    (total_tokens * cost_per_token).ceil
  end
end

# == Schema Information
#
# Table name: llm_feature_credit_costs
#
#  id                 :bigint           not null, primary key
#  llm_model_id       :bigint           not null
#  feature_name       :string           not null
#  credits_per_token  :decimal(10, 4)   default(1.0), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_llm_feature_credit_costs_on_llm_model_id                 (llm_model_id)
#  index_llm_feature_credit_costs_on_llm_model_id_and_feature_name (llm_model_id,feature_name) UNIQUE
#
