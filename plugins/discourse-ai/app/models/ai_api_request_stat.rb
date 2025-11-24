# frozen_string_literal: true

class AiApiRequestStat < ActiveRecord::Base
  before_validation :set_bucket_date
  scope :between, ->(from, to) { where(bucket_date: from..to) }

  class << self
    def record_from_audit_log(log, llm_model:)
      timestamp = log.created_at || Time.zone.now

      create!(
        bucket_date: timestamp,
        user_id: log.user_id,
        provider_id: log.provider_id,
        llm_id: log.llm_id || llm_model&.id,
        language_model: log.language_model,
        feature_name: log.feature_name.presence,
        request_tokens: log.request_tokens || 0,
        response_tokens: log.response_tokens || 0,
        cache_read_tokens: log.cache_read_tokens || 0,
        cache_write_tokens: log.cache_write_tokens || 0,
        usage_count: 1,
        rolled_up: false,
        created_at: timestamp,
        updated_at: Time.zone.now,
      )
    rescue StandardError => e
      Rails.logger.warn("Failed to persist AiApiRequestStat: #{e.message}")
    end

    def rollup!
      cutoff = SiteSetting.ai_usage_rollup_after_days.days.ago.end_of_day

      # We can't easily group by DATE(bucket_date) and delete efficiently in one go if we use slice on dates.
      # Instead, let's pick distinct dates that need rolling up.

      target_dates =
        where(rolled_up: false).where("bucket_date <= ?", cutoff).pluck(
          "DISTINCT DATE(bucket_date)",
        )

      target_dates.each do |date|
        start_time = date.beginning_of_day
        end_time = date.end_of_day

        transaction do
          DB.exec(<<~SQL, start_time: start_time, end_time: end_time, now: Time.zone.now)
            INSERT INTO ai_api_request_stats (
              bucket_date,
              user_id,
              provider_id,
              llm_id,
              language_model,
              feature_name,
              request_tokens,
              response_tokens,
              cache_read_tokens,
              cache_write_tokens,
              usage_count,
              rolled_up,
              created_at,
              updated_at
            )
            SELECT
              :start_time,
              user_id,
              provider_id,
              llm_id,
              language_model,
              feature_name,
              SUM(request_tokens),
              SUM(response_tokens),
              SUM(cache_read_tokens),
              SUM(cache_write_tokens),
              SUM(usage_count),
              true,
              :now,
              :now
            FROM ai_api_request_stats
            WHERE bucket_date >= :start_time
              AND bucket_date <= :end_time
              AND rolled_up = false
            GROUP BY
              user_id,
              provider_id,
              llm_id,
              language_model,
              feature_name
          SQL

          DB.exec(<<~SQL, start_time: start_time, end_time: end_time)
            DELETE FROM ai_api_request_stats
            WHERE bucket_date >= :start_time
              AND bucket_date <= :end_time
              AND rolled_up = false
          SQL
        end
      end
    end
  end

  private

  def set_bucket_date
    self.bucket_date ||= created_at || Time.zone.now
  end
end

# == Schema Information
#
# Table name: ai_api_request_stats
#
#  id                 :bigint           not null, primary key
#  bucket_date        :datetime         not null
#  cache_read_tokens  :integer          default(0), not null
#  cache_write_tokens :integer          default(0), not null
#  feature_name       :string(255)
#  language_model     :string(255)
#  request_tokens     :integer          default(0), not null
#  response_tokens    :integer          default(0), not null
#  rolled_up          :boolean          default(FALSE), not null
#  usage_count        :integer          default(1), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  llm_id             :integer
#  provider_id        :integer          not null
#  user_id            :integer
#
# Indexes
#
#  index_ai_api_request_stats_on_bucket_date_and_feature_name    (bucket_date,feature_name)
#  index_ai_api_request_stats_on_bucket_date_and_language_model  (bucket_date,language_model)
#  index_ai_api_request_stats_on_bucket_date_and_llm_id          (bucket_date,llm_id)
#  index_ai_api_request_stats_on_bucket_date_and_rolled_up       (bucket_date,rolled_up) WHERE (rolled_up = false)
#  index_ai_api_request_stats_on_bucket_date_and_user_id         (bucket_date,user_id)
#  index_ai_api_request_stats_on_created_at_and_feature_name     (created_at,feature_name)
#  index_ai_api_request_stats_on_created_at_and_language_model   (created_at,language_model)
#  index_ai_api_request_stats_on_created_at_and_user_id          (created_at,user_id)
#
