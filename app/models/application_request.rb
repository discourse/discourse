# frozen_string_literal: true
class ApplicationRequest < ActiveRecord::Base
  enum :req_type,
       {
         http_total: 0,
         http_2xx: 1,
         http_background: 2,
         http_3xx: 3,
         http_4xx: 4,
         http_5xx: 5,
         page_view_crawler: 6,
         page_view_logged_in: 7,
         page_view_anon: 8,
         page_view_logged_in_mobile: 9,
         page_view_anon_mobile: 10,
         api: 11,
         user_api: 12,
         page_view_anon_browser: 13,
         page_view_anon_browser_mobile: 14,
         page_view_logged_in_browser: 15,
         page_view_logged_in_browser_mobile: 16,
         page_view_anon_browser_beacon: 17,
         page_view_anon_browser_mobile_beacon: 18,
         page_view_logged_in_browser_beacon: 19,
         page_view_logged_in_browser_mobile_beacon: 20,
         page_view_embed: 21,
       }

  include CachedCounting

  def self.browser_pageviews
    legacy_types = %i[page_view_anon_browser page_view_logged_in_browser]
    beacon_types = %i[page_view_anon_browser_beacon page_view_logged_in_browser_beacon]
    cutover_date = browser_pageview_beacon_cutover_date

    return where(req_type: legacy_types) if cutover_date.nil?

    # Both transports can record the same visit, so select one source for each date.
    where(req_type: legacy_types).where("date < ?", cutover_date).or(
      where(req_type: beacon_types).where("date >= ?", cutover_date),
    )
  end

  def self.browser_pageview_beacon_cutover_date
    first_beacon_date =
      where(req_type: %i[page_view_anon_browser_beacon page_view_logged_in_browser_beacon]).where(
        "count > 0",
      ).minimum(:date)
    return if first_beacon_date.nil?

    # The first beacon day may be partial. Prefer existing piggyback traffic for that
    # whole day, but retain the first day on sites that only recorded beacons.
    if where(
         date: first_beacon_date,
         req_type: %i[page_view_anon_browser page_view_logged_in_browser],
       ).where("count > 0").exists?
      first_beacon_date.next_day
    else
      first_beacon_date
    end
  end

  def self.browser_pageview_count_for_period(type, since)
    browser_pageviews
      .where(req_type: [type, "#{type}_beacon"])
      .where("date >= ?", since)
      .sum(:count)
  end

  def self.disable
    @disabled = true
  end

  def self.enable
    @disabled = false
  end

  def self.increment!(req_type)
    return if @disabled
    perform_increment!(req_type)
  end

  def self.write_cache!(req_type, count, date)
    req_type_id = req_types[req_type]

    DB.exec(<<~SQL, date: date, req_type_id: req_type_id, count: count)
      INSERT INTO application_requests (date, req_type, count)
      VALUES (:date, :req_type_id, :count)
      ON CONFLICT (date, req_type)
      DO UPDATE SET count = application_requests.count + excluded.count
    SQL
  end

  def self.stats
    s = ActiveSupport::HashWithIndifferentAccess.new({})

    req_types.each do |key, i|
      query = where(req_type: i)
      s["#{key}_total"] = query.sum(:count)
      s["#{key}_30_days"] = query.where("date > ?", 30.days.ago).sum(:count)
      s["#{key}_28_days"] = query.where("date > ?", 28.days.ago).sum(:count)
      s["#{key}_7_days"] = query.where("date > ?", 7.days.ago).sum(:count)
    end

    s
  end

  def self.request_type_count_for_period(type, since)
    id = req_types[type]
    if !id
      raise ArgumentError.new(
              "unknown request type #{type.inspect} in ApplicationRequest.req_types",
            )
    end

    where(req_type: id).where("date >= ?", since).sum(:count)
  end
end

# == Schema Information
#
# Table name: application_requests
#
#  id       :integer          not null, primary key
#  count    :integer          default(0), not null
#  date     :date             not null
#  req_type :integer          not null
#
# Indexes
#
#  index_application_requests_on_date_and_req_type  (date,req_type) UNIQUE
#
