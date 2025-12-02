# frozen_string_literal: true

class LlmCreditDailyUsage < ActiveRecord::Base
  self.table_name = "llm_credit_daily_usages"

  belongs_to :llm_model

  validates :llm_model_id, presence: true
  validates :usage_date, presence: true
  validates :credits_used,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
            }

  def self.find_or_create_for_today(llm_model)
    find_or_create_by!(llm_model: llm_model, usage_date: Date.current)
  end

  def self.increment_usage!(llm_model, credits)
    usage = find_or_create_for_today(llm_model)
    usage.with_lock { usage.increment!(:credits_used, credits) }
  end

  def self.usage_for_date(llm_model, date)
    find_by(llm_model: llm_model, usage_date: date)&.credits_used || 0
  end

  def self.cleanup_old_records!(retention_days)
    cutoff = retention_days.days.ago.to_date
    where("usage_date < ?", cutoff).delete_all
  end
end

# == Schema Information
#
# Table name: llm_credit_daily_usages
#
#  id            :bigint           not null, primary key
#  llm_model_id  :bigint           not null
#  usage_date    :date             not null
#  credits_used  :bigint           default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_llm_credit_daily_usages_on_llm_model_id               (llm_model_id)
#  index_llm_credit_daily_usages_on_llm_model_id_and_usage_date  (llm_model_id,usage_date) UNIQUE
#
