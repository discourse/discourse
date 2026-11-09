# frozen_string_literal: true

class DecisionModelCreditAllocation < ActiveRecord::Base
  belongs_to :decision_model

  validates :decision_model_id, presence: true, uniqueness: true
  validates :daily_credits, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :soft_limit_percentage,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100,
            }

  def self.credits_available?(decision_model, feature_name)
    return true if !decision_model&.credit_system_enabled?
    if DecisionModelFeatureCreditCost.credit_cost_for(decision_model, feature_name).zero?
      return true
    end

    !decision_model.decision_model_credit_allocation.hard_limit_reached?
  end

  def self.check_credits!(decision_model, feature_name)
    if !credits_available?(decision_model, feature_name)
      allocation = decision_model.decision_model_credit_allocation
      raise DiscourseAi::Decisions::CreditLimitExceeded.new(
              I18n.t(
                "discourse_ai.decision_models.credit_limit_exceeded",
                model_name: decision_model.display_name,
                reset_time: allocation.relative_reset_time,
              ),
              allocation:,
            )
    end
  end

  def self.deduct_credits!(decision_model, feature_name, tokens)
    return if !decision_model&.credit_system_enabled?

    credits =
      DecisionModelFeatureCreditCost.calculate_credit_cost(decision_model, feature_name, tokens)
    DecisionModelCreditDailyUsage.increment_usage!(decision_model, credits) if credits > 0
  end

  def daily_used
    DecisionModelCreditDailyUsage.usage_for_date(decision_model_id, Date.current)
  end

  def credits_remaining
    [0, daily_credits - daily_used].max
  end

  def percentage_used
    [(daily_used.to_f / daily_credits * 100).round(2), 100].min
  end

  def percentage_remaining
    (credits_remaining.to_f / daily_credits * 100).round(2)
  end

  def soft_limit_reached?
    percentage_used >= soft_limit_percentage
  end

  def hard_limit_reached?
    daily_used >= daily_credits
  end

  def next_reset_at
    Time.current.utc.tomorrow.beginning_of_day
  end

  def relative_reset_time
    AgeWords.distance_of_time_in_words(Time.current, next_reset_at)
  end
end

# == Schema Information
#
# Table name: decision_model_credit_allocations
#
#  id                    :bigint           not null, primary key
#  daily_credits         :bigint           not null
#  soft_limit_percentage :integer          default(80), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  decision_model_id     :bigint           not null
#
# Indexes
#
#  index_decision_model_credit_allocations_on_decision_model_id  (decision_model_id) UNIQUE
#
