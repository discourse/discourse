# encoding: UTF-8
# frozen_string_literal: true

require 'rails_helper'

describe 'rate limiter integration' do

  before do
    RateLimiter.enable
    RateLimiter.clear_all!
  end

  after do
    RateLimiter.disable
  end

  it "will rate limit message bus requests once queueing" do
    freeze_time

    global_setting :reject_message_bus_queue_seconds, 0.1

    post "/message-bus/#{SecureRandom.hex}/poll", headers: {
      "HTTP_X_REQUEST_START" => "t=#{Time.now.to_f - 0.2}"
    }

    expect(response.status).to eq(429)
    expect(response.headers['Retry-After']).to be > 29
  end

  it "will not rate limit when all is good" do
    freeze_time

    global_setting :reject_message_bus_queue_seconds, 0.1

    post "/message-bus/#{SecureRandom.hex}/poll", headers: {
      "HTTP_X_REQUEST_START" => "t=#{Time.now.to_f - 0.05}"
    }

    expect(response.status).to eq(200)
  end

  it "will clear the token cookie if invalid" do
    name = Auth::DefaultCurrentUserProvider::TOKEN_COOKIE

    # we try 11 times because the rate limit is 10
    11.times {
      cookies[name] = SecureRandom.hex
      get '/categories.json'
      expect(response.cookies.has_key?(name)).to eq(true)
      expect(response.cookies[name]).to be_nil
    }
  end

  it 'can cleanly limit requests and sets a Retry-After header' do
    freeze_time
    #request.set_header("action_dispatch.show_exceptions", true)

    admin = Fabricate(:admin)
    api_key = Fabricate(:api_key, key: SecureRandom.hex, user: admin)

    global_setting :max_admin_api_reqs_per_key_per_minute, 1

    get '/admin/api/keys.json', params: {
      api_key: api_key.key,
      api_username: admin.username
    }

    expect(response.status).to eq(200)

    get '/admin/api/keys.json', params: {
      api_key: api_key.key,
      api_username: admin.username
    }

    expect(response.status).to eq(429)

    data = JSON.parse(response.body)

    expect(response.headers['Retry-After']).to eq(60)
    expect(data["extras"]["wait_seconds"]).to eq(60)
  end
end
