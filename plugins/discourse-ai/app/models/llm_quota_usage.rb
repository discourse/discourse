# frozen_string_literal: true

class LlmQuotaUsage < ActiveRecord::Base
  self.table_name = "llm_quota_usages"

  QuotaExceededError = Class.new(StandardError)

  belongs_to :user
  belongs_to :llm_quota

  validates :user_id, presence: true
  validates :llm_quota_id, presence: true
  validates :input_tokens_used, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :output_tokens_used, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :usages, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :started_at, presence: true
  validates :reset_at, presence: true

  def self.find_or_create_for(user:, llm_quota:)
    usage = find_or_initialize_by(user: user, llm_quota: llm_quota)

    if usage.new_record?
      now = Time.current
      usage.started_at = now
      usage.reset_at = now + llm_quota.duration_seconds.seconds
      usage.input_tokens_used = 0
      usage.output_tokens_used = 0
      usage.usages = 0
      usage.save!
    end

    usage
  end

  def reset_if_needed!
    return if Time.current < reset_at

    now = Time.current
    update!(
      input_tokens_used: 0,
      output_tokens_used: 0,
      usages: 0,
      started_at: now,
      reset_at: now + llm_quota.duration_seconds.seconds,
    )
  end

  def increment_usage!(input_tokens:, output_tokens:)
    reset_if_needed!

    increment!(:usages)
    increment!(:input_tokens_used, input_tokens)
    increment!(:output_tokens_used, output_tokens)
  end

  def check_quota!
    reset_if_needed!

    if quota_exceeded?
      raise QuotaExceededError.new(
              I18n.t(
                "discourse_ai.errors.quota_exceeded",
                relative_time: AgeWords.distance_of_time_in_words(reset_at, Time.now),
              ),
            )
    end
  end

  def quota_exceeded?
    return false if !llm_quota

    (llm_quota.max_tokens.present? && total_tokens_used > llm_quota.max_tokens) ||
      (llm_quota.max_usages.present? && usages > llm_quota.max_usages)
  end

  def total_tokens_used
    input_tokens_used + output_tokens_used
  end

  def remaining_tokens
    return nil if llm_quota.max_tokens.nil?
    [0, llm_quota.max_tokens - total_tokens_used].max
  end

  def remaining_usages
    return nil if llm_quota.max_usages.nil?
    [0, llm_quota.max_usages - usages].max
  end

  def percentage_tokens_used
    return 0 if llm_quota.max_tokens.nil? || llm_quota.max_tokens.zero?
    [(total_tokens_used.to_f / llm_quota.max_tokens * 100).round, 100].min
  end

  def percentage_usages_used
    return 0 if llm_quota.max_usages.nil? || llm_quota.max_usages.zero?
    [(usages.to_f / llm_quota.max_usages * 100).round, 100].min
  end
end

# == Schema Information
#
# Table name: llm_quota_usages
#
#  id                 :bigint           not null, primary key
#  user_id            :bigint           not null
#  llm_quota_id       :bigint           not null
#  input_tokens_used  :integer          not null
#  output_tokens_used :integer          not null
#  usages             :integer          not null
#  started_at         :datetime         not null
#  reset_at           :datetime         not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_llm_quota_usages_on_llm_quota_id              (llm_quota_id)
#  index_llm_quota_usages_on_user_id_and_llm_quota_id  (user_id,llm_quota_id) UNIQUE
#
