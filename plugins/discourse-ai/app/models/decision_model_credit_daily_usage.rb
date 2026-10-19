# frozen_string_literal: true

class DecisionModelCreditDailyUsage < ActiveRecord::Base
  belongs_to :decision_model

  validates :decision_model_id, presence: true
  validates :usage_date, presence: true
  validates :credits_used,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
            }

  # Decisions are frequent and cheap, so Redis holds each day's running total and serves every
  # read; a job copies totals into one row per model and day instead of writing on every call.
  FLUSH_INTERVAL = 1.minute
  TOTAL_TTL = 2.days
  DIRTY_KEYS = "discourse_ai:decision_model_credits:dirty"
  FLUSH_SCHEDULED_KEY = "discourse_ai:decision_model_credits:flush_scheduled"

  def self.increment_usage!(decision_model, credits)
    member = member_for(decision_model.id, Date.current)
    key = total_key(member)
    total, _ =
      Discourse.redis.pipelined do |pipeline|
        pipeline.incrby(key, credits)
        pipeline.sadd(DIRTY_KEYS, [member])
      end

    # INCRBY creates a missing total at zero, so only the call that created it adds the
    # persisted usage; otherwise losing Redis would hand out a fresh allowance.
    if total == credits
      persisted = persisted_usage(decision_model.id, Date.current)
      total = Discourse.redis.incrby(key, persisted) if persisted > 0
      Discourse.redis.expire(key, TOTAL_TTL.to_i)
    end

    if Discourse.redis.set(FLUSH_SCHEDULED_KEY, "1", nx: true, ex: FLUSH_INTERVAL.to_i)
      Jobs.enqueue_in(FLUSH_INTERVAL, :flush_decision_model_credit_usage)
    end
    total
  end

  def self.usage_for_date(decision_model_id, date)
    key = total_key(member_for(decision_model_id, date))
    total = Discourse.redis.get(key)
    return total.to_i if total

    # Losing Redis must not hand out a fresh allowance, so a missing total restarts from the row.
    persisted = persisted_usage(decision_model_id, date)
    Discourse.redis.set(key, persisted, nx: true, ex: TOTAL_TTL.to_i)
    Discourse.redis.get(key).to_i
  end

  # Totals are absolute, so flushing twice or concurrently is harmless.
  def self.flush_pending!
    members = Discourse.redis.smembers(DIRTY_KEYS)
    existing_ids =
      DecisionModel.where(id: members.map { |member| member.split(":").first }).pluck(:id)

    members.each do |member|
      Discourse.redis.srem(DIRTY_KEYS, [member])
      total = Discourse.redis.get(total_key(member))
      decision_model_id, usage_date = member.split(":")
      next if total.nil? || !existing_ids.include?(decision_model_id.to_i)

      begin
        persist!(decision_model_id.to_i, Date.parse(usage_date), total.to_i)
      rescue StandardError
        Discourse.redis.sadd(DIRTY_KEYS, [member])
        raise
      end
    end
  end

  # Bypasses the query cache, which would otherwise serve a row from before the last flush.
  def self.persisted_usage(decision_model_id, date)
    DB.query_single(<<~SQL, decision_model_id:, date:).first || 0
      SELECT credits_used FROM decision_model_credit_daily_usages
      WHERE decision_model_id = :decision_model_id AND usage_date = :date
    SQL
  end
  private_class_method :persisted_usage

  # GREATEST keeps a Redis total that was lost and reseeded low from erasing recorded usage.
  def self.persist!(decision_model_id, usage_date, total)
    DB.exec(<<~SQL, decision_model_id:, usage_date:, total:)
      INSERT INTO decision_model_credit_daily_usages
        (decision_model_id, usage_date, credits_used, created_at, updated_at)
      VALUES (:decision_model_id, :usage_date, :total, NOW(), NOW())
      ON CONFLICT (decision_model_id, usage_date)
      DO UPDATE SET
        credits_used = GREATEST(decision_model_credit_daily_usages.credits_used, EXCLUDED.credits_used),
        updated_at = NOW()
    SQL
  end
  private_class_method :persist!

  def self.member_for(decision_model_id, date)
    "#{decision_model_id}:#{date.iso8601}"
  end
  private_class_method :member_for

  def self.total_key(member)
    "discourse_ai:decision_model_credits:total:#{member}"
  end
  private_class_method :total_key
end

# == Schema Information
#
# Table name: decision_model_credit_daily_usages
#
#  id                :bigint           not null, primary key
#  credits_used      :bigint           default(0), not null
#  usage_date        :date             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  decision_model_id :bigint           not null
#
# Indexes
#
#  idx_on_decision_model_id_usage_date_85aaac4721  (decision_model_id,usage_date) UNIQUE
#
