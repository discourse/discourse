# frozen_string_literal: true

class BrowserPageviewEvent < ActiveRecord::Base
  MAX_SESSION_ID_LENGTH = 32
  MAX_URL_LENGTH = 2000
  MAX_REFERRER_LENGTH = 2000
  MAX_USER_AGENT_LENGTH = 1000
  MAX_NORMALIZED_REFERRER_LENGTH = 2000
  RETENTION_PERIOD = 3.months
  SOURCE_PIGGYBACK = 1
  SOURCE_BEACON = 2
  REDIS_QUEUE_KEY = "browser_pageview_events:pending"
  REDIS_FLUSH_LOCK_KEY = "browser_pageview_events:flush"
  REDIS_FLUSH_BATCH_SIZE = 1000
  REDIS_QUEUE_MAX_SIZE = 1_000_000
  REDIS_QUEUE_TTL = 1.day

  enum :source, { piggyback: SOURCE_PIGGYBACK, beacon: SOURCE_BEACON }, scopes: false

  class << self
    def enqueue_for_later(payload)
      return unless valid_payload?(payload)
      return if Discourse.redis.llen(REDIS_QUEUE_KEY) >= REDIS_QUEUE_MAX_SIZE

      Discourse.redis.multi do |transaction|
        transaction.rpush(REDIS_QUEUE_KEY, JSON.generate(serialize_payload(payload)))
        transaction.expire(REDIS_QUEUE_KEY, REDIS_QUEUE_TTL)
      end
    rescue Redis::BaseConnectionError => e
      Rails.logger.warn("Failed to queue BrowserPageviewEvent in Redis: #{e.message}")
    end

    def create_from_payload!(payload)
      BrowserPageviewEvent.create!(attributes_from_payload(payload))
    end

    def flush_queued!
      return 0 if Discourse.pg_readonly_mode?

      processed = 0

      DistributedMutex.synchronize(REDIS_FLUSH_LOCK_KEY, validity: 5.minutes) do
        entries = Array(Discourse.redis.lrange(REDIS_QUEUE_KEY, 0, REDIS_FLUSH_BATCH_SIZE - 1))
        queued_attributes = []

        entries.each do |entry|
          queued_attributes << attributes_from_payload(deserialize_payload(entry))
          processed += 1
        rescue => e
          Rails.logger.error("Discarding queued BrowserPageviewEvent: #{e.message}")
          queued_attributes << nil
          processed += 1
        end

        begin
          insert_rows!(queued_attributes)
        rescue ActiveRecord::ReadOnlyError
          Discourse.received_postgres_readonly!
          return 0
        rescue ActiveRecord::StatementInvalid => e
          if postgres_readonly_error?(e)
            Discourse.received_postgres_readonly!
            return 0
          end

          return 0 if postgres_connection_error?(e)

          Rails.logger.error("Failed to insert queued BrowserPageviewEvents: #{e.message}")
          return 0
        end
      end

      processed
    end

    def queued_count
      Discourse.redis.llen(REDIS_QUEUE_KEY).to_i
    end

    def beacon_cutover_date
      return if SiteSetting.use_legacy_pageviews
      return if !UpcomingChanges.enabled?(:dashboard_improvements)
      if !SiteSetting.trigger_browser_pageview_events &&
           !SiteSetting.persist_browser_pageview_events
        return
      end

      enabled_at = [
        UpcomingChangeEvent.where(
          upcoming_change_name: "dashboard_improvements",
          event_type: %i[manual_opt_in automatically_promoted],
        ).maximum(:created_at),
        SiteSetting.where(name: "dashboard_improvements").maximum(:updated_at),
      ].compact.max

      return enabled_at.utc.to_date.tomorrow if enabled_at

      ApplicationRequest.where(
        req_type: %w[page_view_logged_in_browser_beacon page_view_anon_browser_beacon],
      ).minimum(:date)
    end

    def clear_queued!
      Discourse.redis.del(REDIS_QUEUE_KEY)
    end

    def postgres_readonly_error?(error)
      error.cause.is_a?(PG::ReadOnlySqlTransaction)
    end

    private

    def insert_rows!(queued_attributes)
      return if queued_attributes.blank?

      rows = queued_attributes.compact
      if rows.present?
        BrowserPageviewEvent.transaction(requires_new: true) do
          BrowserPageviewEvent.insert_all(rows, returning: false)
        end
      end
      Discourse.redis.ltrim(REDIS_QUEUE_KEY, queued_attributes.length, -1)
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error(
        "Failed to insert queued BrowserPageviewEvents in bulk; retrying individually: #{e.message}",
      )
      insert_rows_individually!(queued_attributes)
    end

    def insert_rows_individually!(queued_attributes)
      queued_attributes.each do |attributes|
        if attributes
          BrowserPageviewEvent.transaction(requires_new: true) do
            BrowserPageviewEvent.insert_all([attributes], returning: false)
          end
        end
        Discourse.redis.ltrim(REDIS_QUEUE_KEY, 1, -1)
      rescue ActiveRecord::StatementInvalid => e
        raise if postgres_readonly_error?(e) || postgres_connection_error?(e)

        Rails.logger.error(
          "Discarding queued BrowserPageviewEvent after insert failure: #{e.message}",
        )
        Discourse.redis.ltrim(REDIS_QUEUE_KEY, 1, -1)
      end
    end

    def serialize_payload(payload)
      payload = payload.with_indifferent_access

      {
        user_id: payload[:user_id],
        url: payload[:url]&.slice(0, MAX_URL_LENGTH),
        ip_address: payload[:ip_address],
        country_code: payload[:country_code]&.slice(0, 2),
        asn: payload[:asn],
        referrer: payload[:referrer]&.slice(0, MAX_REFERRER_LENGTH),
        user_agent: payload[:user_agent]&.slice(0, MAX_USER_AGENT_LENGTH),
        session_id: payload[:session_id]&.slice(0, MAX_SESSION_ID_LENGTH),
        topic_id: payload[:topic_id],
        source: payload[:source],
        occurred_at: payload[:occurred_at],
      }
    end

    def deserialize_payload(entry)
      JSON.parse(entry).with_indifferent_access
    end

    def attributes_from_payload(payload)
      normalized_referrer = BrowserPageviewReferrerInspector.normalize(payload[:referrer])

      {
        url: payload[:url]&.slice(0, MAX_URL_LENGTH),
        ip_address: payload[:ip_address],
        country_code: payload[:country_code]&.slice(0, 2),
        asn: payload[:asn],
        referrer: payload[:referrer]&.slice(0, MAX_REFERRER_LENGTH),
        normalized_referrer: normalized_referrer&.slice(0, MAX_NORMALIZED_REFERRER_LENGTH),
        normalized_referrer_version: BrowserPageviewReferrerInspector::VERSION,
        user_agent: payload[:user_agent]&.slice(0, MAX_USER_AGENT_LENGTH),
        session_id: payload[:session_id]&.slice(0, MAX_SESSION_ID_LENGTH),
        user_id: payload[:user_id],
        topic_id: payload[:topic_id],
        source: payload[:source],
        created_at: payload[:occurred_at],
      }
    end

    def valid_payload?(payload)
      payload[:url].present? && payload[:ip_address].present? && payload[:user_agent].present? &&
        payload[:session_id].present? && payload[:occurred_at].present? &&
        valid_ip_address?(payload[:ip_address])
    end

    def valid_ip_address?(ip_address)
      IPAddr.new(ip_address)
      true
    rescue IPAddr::Error
      false
    end

    def postgres_connection_error?(error)
      cause = error.cause
      cause.is_a?(PG::ConnectionBad) || cause.is_a?(PG::UnableToSend)
    end
  end

  has_one :browser_pageview_event_score, foreign_key: :event_id, dependent: :delete

  def self.retention_cutoff
    RETENTION_PERIOD.ago.beginning_of_day
  end

  def self.rollup_source
    if UpcomingChanges.enabled?(:dashboard_improvements)
      SOURCE_BEACON
    else
      SOURCE_PIGGYBACK
    end
  end

  before_save :truncate_fields

  private

  def truncate_fields
    self.url = url.slice(0, MAX_URL_LENGTH) if url.present?
    self.referrer = referrer.slice(0, MAX_REFERRER_LENGTH) if referrer.present?
    self.user_agent = user_agent.slice(0, MAX_USER_AGENT_LENGTH) if user_agent.present?
    self.session_id = session_id.slice(0, MAX_SESSION_ID_LENGTH) if session_id.present?
    if normalized_referrer.present?
      self.normalized_referrer = normalized_referrer.slice(0, MAX_NORMALIZED_REFERRER_LENGTH)
    end
  end
end

# == Schema Information
#
# Table name: browser_pageview_events
#
#  id                          :bigint           not null, primary key
#  asn                         :integer
#  country_code                :string(2)
#  ip_address                  :inet             not null
#  normalized_referrer         :string(2000)
#  normalized_referrer_version :integer
#  referrer                    :string(2000)
#  score                       :integer
#  source                      :integer          default("piggyback"), not null
#  url                         :string(2000)     not null
#  user_agent                  :string(1000)     not null
#  created_at                  :datetime         not null
#  session_id                  :string(32)       not null
#  topic_id                    :integer
#  user_id                     :integer
#
# Indexes
#
#  idx_bpe_created_at_country_code              (created_at,country_code)
#  idx_bpe_created_at_normalized_referrer       (created_at,normalized_referrer)
#  idx_bpe_ip_ua_created_at                     (ip_address,user_agent,created_at)
#  idx_bpe_normalized_referrer_version          (normalized_referrer_version) WHERE (referrer IS NOT NULL)
#  idx_bpe_session_created_at                   (session_id,created_at)
#  index_browser_pageview_events_on_created_at  (created_at) USING brin
#  index_browser_pageview_events_on_topic_id    (topic_id)
#  index_browser_pageview_events_on_user_id     (user_id)
#
