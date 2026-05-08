# frozen_string_literal: true

class BrowserPageviewEvent < ActiveRecord::Base
  EXCLUDED_COUNTRY_CODES = %w[ZZ XX T1]
  MAX_SESSION_ID_LENGTH = 32
  MAX_URL_LENGTH = 2000
  MAX_REFERRER_LENGTH = 2000
  MAX_USER_AGENT_LENGTH = 1000

  has_one :browser_pageview_event_score, foreign_key: :event_id, dependent: :delete

  before_save :truncate_fields

  class << self
    def defer_record!(payload)
      Scheduler::Defer.later("Persist browser pageview event") { record!(payload) }
    end

    def record!(payload)
      attributes = event_attributes(payload)
      return if missing_required_attributes?(attributes)

      create!(attributes)
    end

    def null_user!(user_id)
      where(user_id: user_id).update_all(user_id: nil)
    end

    def null_ip_addresses_older_than(cutoff)
      where("created_at < ? AND ip_address IS NOT NULL", cutoff).update_all(ip_address: nil)
    end

    def purge_older_than(cutoff)
      where("created_at < ?", cutoff).delete_all
    end

    private

    def event_attributes(payload)
      ip_address = payload[:ip_address].presence

      {
        created_at: payload[:occurred_at].presence || Time.zone.now,
        url: truncate(payload[:url], MAX_URL_LENGTH),
        ip_address: ip_address,
        referrer: truncate(payload[:referrer], MAX_REFERRER_LENGTH),
        user_agent: truncate(payload[:user_agent], MAX_USER_AGENT_LENGTH),
        session_id: truncate(payload[:session_id], MAX_SESSION_ID_LENGTH),
        country_code:
          normalize_country_code(payload[:country_code] || lookup_country_code(ip_address)),
        user_id: payload[:user_id].presence,
        topic_id: payload[:topic_id].presence,
      }
    end

    def truncate(value, limit)
      value.presence&.to_s&.slice(0, limit)
    end

    def normalize_country_code(country_code)
      country_code = country_code.to_s.upcase
      return if country_code.blank? || EXCLUDED_COUNTRY_CODES.include?(country_code)
      return if country_code !~ /\A[A-Z]{2}\z/

      country_code
    end

    def lookup_country_code(ip_address)
      return if ip_address.blank?

      DiscourseIpInfo.get(ip_address)[:country_code]
    end

    def missing_required_attributes?(attributes)
      attributes[:url].blank? || attributes[:ip_address].blank? || attributes[:user_agent].blank? ||
        attributes[:session_id].blank?
    end
  end

  private

  def truncate_fields
    self.url = url.slice(0, MAX_URL_LENGTH) if url.present?
    self.referrer = referrer.slice(0, MAX_REFERRER_LENGTH) if referrer.present?
    self.user_agent = user_agent.slice(0, MAX_USER_AGENT_LENGTH) if user_agent.present?
    self.session_id = session_id.slice(0, MAX_SESSION_ID_LENGTH) if session_id.present?
  end
end

# == Schema Information
#
# Table name: browser_pageview_events
#
#  id           :bigint           not null, primary key
#  asn          :integer
#  country_code :string(2)
#  ip_address   :inet
#  referrer     :string(2000)
#  score        :integer
#  url          :string(2000)     not null
#  user_agent   :string(1000)     not null
#  created_at   :datetime         not null
#  session_id   :string(32)       not null
#  topic_id     :integer
#  user_id      :integer
#
# Indexes
#
#  idx_bpe_ip_ua_created_at                     (ip_address,user_agent,created_at)
#  idx_bpe_session_created_at                   (session_id,created_at)
#  index_browser_pageview_events_on_created_at  (created_at) USING brin
#  index_browser_pageview_events_on_topic_id    (topic_id)
#  index_browser_pageview_events_on_user_id     (user_id)
#
