class WebCrawlerRequest < ActiveRecord::Base
  include CachedCounting

  # auto flush if older than this
  self.autoflush_seconds = 1.hour

  cattr_accessor :max_record_age, :max_records_per_day

  # only keep the top records based on request count
  self.max_records_per_day = 200

  # delete records older than this
  self.max_record_age = 30.days

  def self.increment!(user_agent, opts = nil)
    ua_list_key = user_agent_list_key
    $redis.sadd(ua_list_key, user_agent)
    $redis.expire(ua_list_key, 259200) # 3.days

    perform_increment!(redis_key(user_agent), opts)
  end

  def self.write_cache!(date = nil)
    if date.nil?
      write_cache!(Time.now.utc)
      write_cache!(Time.now.utc.yesterday)
      return
    end

    self.last_flush = Time.now.utc

    date = date.to_date
    ua_list_key = user_agent_list_key(date)

    while user_agent = $redis.spop(ua_list_key)
      val = get_and_reset(redis_key(user_agent, date))

      next if val == 0

      self.where(id: req_id(date, user_agent)).update_all(["count = count + ?", val])
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

    ua_list_key = user_agent_list_key(date)

    while user_agent = $redis.spop(ua_list_key)
      $redis.del redis_key(user_agent, date)
    end

    $redis.del(ua_list_key)
  end

  protected

  def self.user_agent_list_key(time = Time.now.utc)
    "crawl_ua_list:#{time.strftime('%Y%m%d')}"
  end

  def self.redis_key(user_agent, time = Time.now.utc)
    "crawl_req:#{time.strftime('%Y%m%d')}:#{user_agent}"
  end

  def self.req_id(date, user_agent)
    request_id(date: date, user_agent: user_agent)
  end
end

# == Schema Information
#
# Table name: web_crawler_requests
#
#  id         :integer          not null, primary key
#  date       :date             not null
#  user_agent :string           not null
#  count      :integer          default(0), not null
#
# Indexes
#
#  index_web_crawler_requests_on_date_and_user_agent  (date,user_agent) UNIQUE
#
