# frozen_string_literal: true

require 'rails_helper'

describe WebCrawlerRequest do
  before do
    WebCrawlerRequest.last_flush = Time.now.utc
    WebCrawlerRequest.clear_cache!
  end

  after do
    WebCrawlerRequest.clear_cache!
  end

  def inc(user_agent, opts = nil)
    WebCrawlerRequest.increment!(user_agent, opts)
  end

  def disable_date_flush!
    freeze_time(Time.now)
    WebCrawlerRequest.last_flush = Time.now.utc
  end

  def web_crawler_request(user_agent)
    WebCrawlerRequest.where(user_agent: user_agent).first
  end

  it 'works even if redis is in readonly' do
    disable_date_flush!

    inc('Googlebot')
    inc('Googlebot')

    Discourse.redis.without_namespace.stubs(:incr).raises(Redis::CommandError.new("READONLY"))
    Discourse.redis.without_namespace.stubs(:eval).raises(Redis::CommandError.new("READONLY"))

    inc('Googlebot', autoflush: 3)
    WebCrawlerRequest.write_cache!

    Discourse.redis.without_namespace.unstub(:incr)
    Discourse.redis.without_namespace.unstub(:eval)

    inc('Googlebot', autoflush: 3)
    expect(web_crawler_request('Googlebot').count).to eq(3)
  end

  it 'logs nothing for an unflushed increment' do
    WebCrawlerRequest.increment!('Googlebot')
    expect(WebCrawlerRequest.count).to eq(0)
  end

  it 'can automatically flush' do
    disable_date_flush!

    inc('Googlebot', autoflush: 3)
    expect(web_crawler_request('Googlebot')).to_not be_present
    expect(WebCrawlerRequest.count).to eq(0)
    inc('Googlebot', autoflush: 3)
    expect(web_crawler_request('Googlebot')).to_not be_present
    inc('Googlebot', autoflush: 3)
    expect(web_crawler_request('Googlebot').count).to eq(3)
    expect(WebCrawlerRequest.count).to eq(1)

    3.times { inc('Googlebot', autoflush: 3) }
    expect(web_crawler_request('Googlebot').count).to eq(6)
    expect(WebCrawlerRequest.count).to eq(1)
  end

  it 'can flush based on time' do
    t1 = Time.now.utc.at_midnight
    freeze_time(t1)
    WebCrawlerRequest.write_cache!
    inc('Googlebot')
    expect(WebCrawlerRequest.count).to eq(0)

    freeze_time(t1 + WebCrawlerRequest.autoflush_seconds + 1)
    inc('Googlebot')

    expect(WebCrawlerRequest.count).to eq(1)
  end

  it 'flushes yesterdays results' do
    t1 = Time.now.utc.at_midnight
    freeze_time(t1)
    inc('Googlebot')
    freeze_time(t1.tomorrow)
    inc('Googlebot')

    WebCrawlerRequest.write_cache!
    expect(WebCrawlerRequest.count).to eq(2)
  end

  it 'clears cache correctly' do
    inc('Googlebot')
    inc('Twitterbot')
    WebCrawlerRequest.clear_cache!
    WebCrawlerRequest.write_cache!

    expect(WebCrawlerRequest.count).to eq(0)
  end

  it 'logs a few counts once flushed' do
    time = Time.now.at_midnight
    freeze_time(time)

    3.times { inc('Googlebot') }
    2.times { inc('Twitterbot') }
    4.times { inc('Bingbot') }

    WebCrawlerRequest.write_cache!

    expect(web_crawler_request('Googlebot').count).to eq(3)
    expect(web_crawler_request('Twitterbot').count).to eq(2)
    expect(web_crawler_request('Bingbot').count).to eq(4)
  end
end
