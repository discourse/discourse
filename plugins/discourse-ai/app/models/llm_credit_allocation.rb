# frozen_string_literal: true

class LlmCreditAllocation < ActiveRecord::Base
  self.table_name = "llm_credit_allocations"

  class CreditLimitExceeded < StandardError
    attr_reader :allocation

    def initialize(message, allocation: nil)
      super(message)
      @allocation = allocation
    end
  end

  belongs_to :llm_model

  # TODO: Remove once 20251105174002_refactor_llm_credit_allocation_to_monthly_usage has been promoted to pre-deploy
  self.ignored_columns = %w[monthly_used last_reset_at]

  validates :llm_model_id, presence: true, uniqueness: true
  validates :monthly_credits, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :soft_limit_percentage,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100,
            }

  def current_month_key
    Time.current.strftime("%Y-%m")
  end

  def monthly_used
    monthly_usage[current_month_key].to_i
  end

  def monthly_used=(value)
    month_key = current_month_key
    self.monthly_usage = (monthly_usage || {}).merge(month_key => value.to_i)
  end

  def credits_remaining
    [0, monthly_credits - monthly_used].max
  end

  def percentage_used
    return 0 if monthly_credits.zero?
    [(monthly_used.to_f / monthly_credits * 100).round(2), 100].min
  end

  def percentage_remaining
    return 100.0 if monthly_credits.zero?
    [(credits_remaining.to_f / monthly_credits * 100).round(2), 0].max
  end

  def soft_limit_reached?
    percentage_used >= soft_limit_percentage
  end

  def soft_limit_remaining_reached?
    percentage_remaining <= (100 - soft_limit_percentage)
  end

  def hard_limit_reached?
    monthly_used >= monthly_credits
  end

  def hard_limit_remaining_reached?
    credits_remaining <= 0
  end

  def next_reset_at
    Time.current.next_month.beginning_of_month
  end

  def deduct_credits!(credits)
    with_lock do
      reload
      month_key = current_month_key
      self.monthly_usage = monthly_usage.merge(month_key => monthly_used + credits)
      cleanup_old_months!
      save!
    end
  end

  def credits_available?
    !hard_limit_reached?
  end

  def check_credits!
    if hard_limit_reached?
      raise CreditLimitExceeded.new(
              I18n.t(
                "discourse_ai.llm_credit_allocation.limit_exceeded",
                reset_time: format_reset_time,
              ),
              allocation: self,
            )
    end
  end

  def self.credits_available?(llm_model)
    return true unless llm_model&.credit_system_enabled?

    allocation = llm_model.llm_credit_allocation
    return true unless allocation

    allocation.credits_available?
  end

  def self.check_credits!(llm_model)
    return unless llm_model&.credit_system_enabled?

    allocation = llm_model.llm_credit_allocation
    allocation.check_credits!
  end

  def self.deduct_credits!(llm_model, feature_name, request_tokens, response_tokens)
    return unless llm_model&.credit_system_enabled?

    total_tokens = request_tokens + response_tokens
    credit_cost = LlmFeatureCreditCost.calculate_credit_cost(llm_model, feature_name, total_tokens)
    llm_model.llm_credit_allocation.deduct_credits!(credit_cost)
  end

  def formatted_reset_time
    return "" if next_reset_at.nil?
    next_reset_at.strftime("%l:%M%P on %b %d, %Y").strip
  end

  def relative_reset_time
    return "" if next_reset_at.nil?
    "in " + AgeWords.distance_of_time_in_words(Time.current, next_reset_at)
  end

  private

  def cleanup_old_months!
    cutoff = 6.months.ago.beginning_of_month.strftime("%Y-%m")
    self.monthly_usage = monthly_usage.select { |k, _| k >= cutoff }
  end

  def format_reset_time
    return "" if next_reset_at.nil?
    AgeWords.distance_of_time_in_words(next_reset_at, Time.now)
  end
end

# == Schema Information
#
# Table name: llm_credit_allocations
#
#  id                    :bigint           not null, primary key
#  monthly_credits       :bigint           not null
#  monthly_usage         :jsonb            not null
#  soft_limit_percentage :integer          default(80), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  llm_model_id          :bigint           not null
#
# Indexes
#
#  index_llm_credit_allocations_on_llm_model_id  (llm_model_id) UNIQUE
#
