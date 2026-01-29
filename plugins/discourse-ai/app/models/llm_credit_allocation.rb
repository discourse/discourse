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
  has_many :daily_usages,
           class_name: "LlmCreditDailyUsage",
           foreign_key: :llm_model_id,
           primary_key: :llm_model_id,
           dependent: :destroy

  # TODO: Remove once column-dropping migrations have been promoted to pre-deploy:
  #   - 20251105174003 (drops monthly_used, last_reset_at)
  #   - 20251117000003 (drops monthly_credits, monthly_usage)
  #   - 20251209180201 (drops daily_usage)
  self.ignored_columns = %w[monthly_used last_reset_at monthly_credits monthly_usage daily_usage]

  validates :llm_model_id, presence: true, uniqueness: true
  validates :daily_credits, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :soft_limit_percentage,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100,
            }

  def daily_used
    # Use llm_credit_daily_usages table
    # Check if association is preloaded to avoid N+1 queries
    if association(:daily_usages).loaded?
      usage_record = daily_usages.find { |u| u.usage_date == Date.current }
      return usage_record.credits_used if usage_record
    else
      usage_record =
        LlmCreditDailyUsage.find_by(llm_model_id: llm_model_id, usage_date: Date.current)
      return usage_record.credits_used if usage_record
    end

    0
  end

  def daily_used=(value)
    usage_record =
      LlmCreditDailyUsage.find_or_create_by!(llm_model_id: llm_model_id, usage_date: Date.current)
    usage_record.update!(credits_used: value.to_i)
  end

  def credits_remaining
    [0, daily_credits - daily_used].max
  end

  def percentage_used
    return 0 if daily_credits.zero?
    [(daily_used.to_f / daily_credits * 100).round(2), 100].min
  end

  def percentage_remaining
    return 100.0 if daily_credits.zero?
    [(credits_remaining.to_f / daily_credits * 100).round(2), 0].max
  end

  def soft_limit_reached?
    percentage_used >= soft_limit_percentage
  end

  def soft_limit_remaining_reached?
    percentage_remaining <= (100 - soft_limit_percentage)
  end

  def hard_limit_reached?
    daily_used >= daily_credits
  end

  def hard_limit_remaining_reached?
    credits_remaining <= 0
  end

  def next_reset_at
    Time.current.utc.tomorrow.beginning_of_day
  end

  def deduct_credits!(credits)
    LlmCreditDailyUsage.increment_usage!(llm_model, credits)
  end

  def credits_available?
    !hard_limit_reached?
  end

  def check_credits!
    raise CreditLimitExceeded.new("Credit limit exceeded", allocation: self) if hard_limit_reached?
  end

  def self.credits_available?(llm_model)
    return true unless llm_model&.credit_system_enabled?

    allocation = llm_model.llm_credit_allocation
    return true unless allocation

    allocation.credits_available?
  end

  def self.check_credits!(llm_model, feature_name = nil)
    return unless llm_model&.credit_system_enabled?

    # If feature has 0 credit cost, skip the check entirely
    if feature_name.present?
      cost_per_token = LlmFeatureCreditCost.credit_cost_for(llm_model, feature_name)
      return if cost_per_token.zero?
    end

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
    AgeWords.distance_of_time_in_words(Time.current, next_reset_at)
  end

  private
end

# == Schema Information
#
# Table name: llm_credit_allocations
#
#  id                    :bigint           not null, primary key
#  daily_credits         :bigint           default(0), not null
#  soft_limit_percentage :integer          default(80), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  llm_model_id          :bigint           not null
#
# Indexes
#
#  index_llm_credit_allocations_on_llm_model_id  (llm_model_id) UNIQUE
#
