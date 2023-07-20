# frozen_string_literal: true

class WebCrawlerRequest < ActiveRecord::Base
  include CachedCounting

  cattr_accessor :max_record_age, :max_records_per_day

  # only keep the top records based on request count
  self.max_records_per_day = 200

  # delete records older than this
  self.max_record_age = 30.days

  def self.increment!(user_agent)
    perform_increment!(user_agent)
  end

  def self.write_cache!(user_agent, count, date)
    where(id: request_id(date: date, user_agent: user_agent)).update_all(
      ["count = count + ?", count],
    )
  end

  protected

  def self.request_id(date:, user_agent:, retries: 0)
    id = where(date: date, user_agent: user_agent).pick(:id)
    id ||= create!({ date: date, user_agent: user_agent }.merge(count: 0)).id
  rescue StandardError # primary key violation
    if retries == 0
      request_id(date: date, user_agent: user_agent, retries: 1)
    else
      raise
    end
  end
end

# == Schema Information
#
# Table name: web_crawler_requests
#
#  id         :bigint           not null, primary key
#  date       :date             not null
#  user_agent :string           not null
#  count      :integer          default(0), not null
#
# Indexes
#
#  index_web_crawler_requests_on_date_and_user_agent  (date,user_agent) UNIQUE
#
