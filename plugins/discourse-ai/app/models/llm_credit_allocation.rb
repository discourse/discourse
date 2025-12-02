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

  DAILY_USAGE_RETENTION_DAYS = 90

  belongs_to :llm_model
  has_many :daily_usages,
           class_name: "LlmCreditDailyUsage",
           foreign_key: :llm_model_id,
           primary_key: :llm_model_id,
           dependent: :destroy

  # TODO: Remove once both column-dropping migrations have been promoted to pre-deploy:
  #   - 20251105174003 (drops monthly_used, last_reset_at)
  #   - 20251117000003 (drops monthly_credits, monthly_usage)
  self.ignored_columns = %w[monthly_used last_reset_at monthly_credits monthly_usage]

  validates :llm_model_id, presence: true, uniqueness: true
  validates :daily_credits, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :soft_limit_percentage,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100,
            }

  # DEPRECATED: Used for JSONB daily_usage column which is being phased out
  # TODO: Remove once daily_usage column is dropped
  def current_day_key
    Time.current.utc.strftime("%Y-%m-%d")
  end

  def daily_used
    # Primary: Use llm_credit_daily_usages table
    usage_record = LlmCreditDailyUsage.find_by(llm_model_id: llm_model_id, usage_date: Date.current)
    return usage_record.credits_used if usage_record

    # DEPRECATED: Fallback to JSONB daily_usage column for backwards compatibility
    # TODO: Remove this fallback once daily_usage column is dropped and added to ignored_columns
    return daily_usage[current_day_key].to_i if respond_to?(:daily_usage) && daily_usage.present?

    0
  end

  def daily_used=(value)
    usage_record =
      LlmCreditDailyUsage.find_or_create_by!(llm_model_id: llm_model_id, usage_date: Date.current)
    usage_record.update!(credits_used: value.to_i)

    # DEPRECATED: Dual-write to JSONB daily_usage column during migration period
    # TODO: Remove this dual-write once daily_usage column is dropped
    if respond_to?(:daily_usage=)
      day_key = current_day_key
      self.daily_usage = (daily_usage || {}).merge(day_key => value.to_i)
    end
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

    # DEPRECATED: Dual-write to JSONB daily_usage column during migration period
    # TODO: Remove this entire block once daily_usage column is dropped
    if respond_to?(:daily_usage=)
      with_lock do
        reload
        day_key = current_day_key
        self.daily_usage = daily_usage.merge(day_key => daily_used + credits)
        cleanup_old_days!
        # Inline JSONB cleanup (original behavior for backwards compatibility)
        cutoff = DAILY_USAGE_RETENTION_DAYS.days.ago.beginning_of_day.utc.strftime("%Y-%m-%d")
        self.daily_usage = daily_usage.select { |k, _| k >= cutoff }

        save!
      end
    end
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
    "in " + AgeWords.distance_of_time_in_words(Time.current, next_reset_at)
  end

  private
end

# == Schema Information
#
# Table name: llm_credit_allocations
#
#  id                    :bigint           not null, primary key
#  daily_credits         :bigint           default(0), not null
#  daily_usage           :jsonb            not null
#  soft_limit_percentage :integer          default(80), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  llm_model_id          :bigint           not null
#
# Indexes
#
#  index_llm_credit_allocations_on_llm_model_id  (llm_model_id) UNIQUE
#
