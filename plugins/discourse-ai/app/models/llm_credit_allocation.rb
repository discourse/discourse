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

  validates :llm_model_id, presence: true, uniqueness: true
  validates :monthly_credits, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :monthly_used,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
            }
  validates :soft_limit_percentage,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100,
            }
  validates :last_reset_at, presence: true

  before_validation :set_last_reset_at, on: :create

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
    return nil if last_reset_at.nil?
    last_reset_at + 1.month
  end

  def reset_if_needed!
    with_lock do
      reload
      return unless should_reset?

      now = Time.current
      update!(monthly_used: 0, last_reset_at: now)
    end
  end

  def should_reset?
    return false if last_reset_at.nil?
    Time.current >= next_reset_at
  end

  def deduct_credits!(credits)
    with_lock do
      self.monthly_used += credits
      save!
    end
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

  def self.check_credits!(llm_model)
    return unless llm_model&.credit_system_enabled?

    allocation = llm_model.llm_credit_allocation
    allocation.reset_if_needed!
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

  def set_last_reset_at
    self.last_reset_at ||= Time.current
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
#  last_reset_at         :datetime         not null
#  monthly_credits       :bigint           not null
#  monthly_used          :bigint           default(0), not null
#  soft_limit_percentage :integer          default(80), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  llm_model_id          :bigint           not null
#
# Indexes
#
#  index_llm_credit_allocations_on_llm_model_id  (llm_model_id) UNIQUE
#
