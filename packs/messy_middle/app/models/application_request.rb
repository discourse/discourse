# frozen_string_literal: true
class ApplicationRequest < ActiveRecord::Base
  enum req_type: %i[
         http_total
         http_2xx
         http_background
         http_3xx
         http_4xx
         http_5xx
         page_view_crawler
         page_view_logged_in
         page_view_anon
         page_view_logged_in_mobile
         page_view_anon_mobile
         api
         user_api
       ]

  include CachedCounting

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
    s = HashWithIndifferentAccess.new({})

    self.req_types.each do |key, i|
      query = self.where(req_type: i)
      s["#{key}_total"] = query.sum(:count)
      s["#{key}_30_days"] = query.where("date > ?", 30.days.ago).sum(:count)
      s["#{key}_7_days"] = query.where("date > ?", 7.days.ago).sum(:count)
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
