# frozen_string_literal: true

class LlmQuota < ActiveRecord::Base
  self.table_name = "llm_quotas"

  belongs_to :group
  belongs_to :llm_model
  has_many :llm_quota_usages

  validates :group_id, presence: true
  # we can not validate on create cause it breaks build
  validates :llm_model_id, presence: true, on: :update
  validates :duration_seconds, presence: true, numericality: { greater_than: 0 }
  validates :max_tokens, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :max_usages, numericality: { greater_than: 0, allow_nil: true }

  validate :at_least_one_limit

  def self.check_quotas!(llm, user)
    return true if user.blank?
    quotas = joins(:group).where(llm_model: llm).where(group: user.groups)

    return true if quotas.empty?
    errors =
      quotas.map do |quota|
        usage = LlmQuotaUsage.find_or_create_for(user: user, llm_quota: quota)
        begin
          usage.check_quota!
          nil
        rescue LlmQuotaUsage::QuotaExceededError => e
          e
        end
      end

    return if errors.include?(nil)

    raise errors.first
  end

  def self.log_usage(llm, user, input_tokens, output_tokens)
    return if user.blank?

    quotas = joins(:group).where(llm_model: llm).where(group: user.groups)

    quotas.each do |quota|
      usage = LlmQuotaUsage.find_or_create_for(user: user, llm_quota: quota)
      usage.increment_usage!(input_tokens: input_tokens, output_tokens: output_tokens)
    end
  end

  def available_tokens
    max_tokens
  end

  def available_usages
    max_usages
  end

  private

  def at_least_one_limit
    if max_tokens.nil? && max_usages.nil?
      errors.add(:base, I18n.t("discourse_ai.errors.quota_required"))
    end
  end
end

# == Schema Information
#
# Table name: llm_quotas
#
#  id               :bigint           not null, primary key
#  group_id         :bigint           not null
#  llm_model_id     :bigint           not null
#  max_tokens       :integer
#  max_usages       :integer
#  duration_seconds :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_llm_quotas_on_group_id_and_llm_model_id  (group_id,llm_model_id) UNIQUE
#  index_llm_quotas_on_llm_model_id               (llm_model_id)
#
