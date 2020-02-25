# frozen_string_literal: true
class ApplicationRequest < ActiveRecord::Base

  enum req_type: %i(http_total
                    http_2xx
                    http_background
                    http_3xx
                    http_4xx
                    http_5xx
                    page_view_crawler
                    page_view_logged_in
                    page_view_anon
                    page_view_logged_in_mobile
                    page_view_anon_mobile)

  include CachedCounting

  def self.increment!(type, opts = nil)
    perform_increment!(redis_key(type), opts)
  end

  def self.write_cache!(date = nil)
    if date.nil?
      write_cache!(Time.now.utc)
      write_cache!(Time.now.utc.yesterday)
      return
    end

    self.last_flush = Time.now.utc

    date = date.to_date

    req_types.each do |req_type, _|
      val = get_and_reset(redis_key(req_type, date))

      next if val == 0

      id = req_id(date, req_type)
      where(id: id).update_all(["count = count + ?", val])
    end
  rescue Redis::CommandError => e
    raise unless e.message =~ /READONLY/
    nil
  end

  def self.clear_cache!(date = nil)
    if date.nil?
      clear_cache!(Time.now.utc)
      clear_cache!(Time.now.utc.yesterday)
      return
    end

    req_types.each do |req_type, _|
      key = redis_key(req_type, date)
      Discourse.redis.del key
    end
  end

  protected

  def self.req_id(date, req_type, retries = 0)

    req_type_id = req_types[req_type]

    # a poor man's upsert
    id = where(date: date, req_type: req_type_id).pluck_first(:id)
    id ||= create!(date: date, req_type: req_type_id, count: 0).id

  rescue # primary key violation
    if retries == 0
      req_id(date, req_type, 1)
    else
      raise
    end
  end

  def self.redis_key(req_type, time = Time.now.utc)
    "app_req_#{req_type}#{time.strftime('%Y%m%d')}"
  end

  def self.stats
    s = HashWithIndifferentAccess.new({})

    self.req_types.each do |key, i|
      query = self.where(req_type: i)
      s["#{key}_total"]   = query.sum(:count)
      s["#{key}_30_days"] = query.where("date > ?", 30.days.ago).sum(:count)
      s["#{key}_7_days"]  = query.where("date > ?", 7.days.ago).sum(:count)
    end

    s
  end
end

# == Schema Information
#
# Table name: application_requests
#
#  id       :integer          not null, primary key
#  date     :date             not null
#  req_type :integer          not null
#  count    :integer          default(0), not null
#
# Indexes
#
#  index_application_requests_on_date_and_req_type  (date,req_type) UNIQUE
#
