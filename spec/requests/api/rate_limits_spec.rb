# frozen_string_literal: true

class MockRateLimiter
  LimitExceeded = RateLimiter::LimitExceeded

  def self.disable
  end

  def self.enable
  end

  def self.performed!(*args, **kwargs)
  end

  def self.rollback!(*args, **kwargs)
  end

  def initialize(*args, **kwargs)
    @args = args
    @kwargs = kwargs
  end

  def can_perform?
    true
  end

  def performed!
    MockRateLimiter.performed!(*@args, **@kwargs)
  end

  def rollback!
    MockRateLimiter.rollback!(*@args, **@kwargs)
  end
end

RSpec.describe "rate limits" do
  before_all { @key = Fabricate(:api_key).key }

  let(:api_key) { @key }
  let!(:api_username) { "system" }

  around(:each) { |example| stub_const(Object, :RateLimiter, MockRateLimiter) { example.run } }

  it "doesn't rate limit authenticated admin api requests" do
    MockRateLimiter
      .expects(:performed!)
      .with(
        nil,
        "global_limit_60_192.0.2.1",
        200,
        60,
        global: true,
        error_code: "ip_60_secs_limit",
        aggressive: true,
      )
      .once
    MockRateLimiter
      .expects(:performed!)
      .with(
        nil,
        "global_limit_10_192.0.2.1",
        50,
        10,
        global: true,
        error_code: "ip_10_secs_limit",
        aggressive: true,
      )
      .once

    MockRateLimiter
      .expects(:performed!)
      .with(nil, "admin_api_min", 60, 60, error_code: "admin_api_key_rate_limit")
      .once

    MockRateLimiter
      .expects(:rollback!)
      .with(
        nil,
        "global_limit_60_192.0.2.1",
        200,
        60,
        global: true,
        error_code: "ip_60_secs_limit",
        aggressive: true,
      )
      .once
    MockRateLimiter
      .expects(:rollback!)
      .with(
        nil,
        "global_limit_10_192.0.2.1",
        50,
        10,
        global: true,
        error_code: "ip_10_secs_limit",
        aggressive: true,
      )
      .once

    get(
      "/admin/backups.json",
      headers: {
        "Api-Key" => api_key,
        "Api-Username" => api_username,
      },
      env: {
        REMOTE_ADDR: "192.0.2.1",
      },
    )

    expect(response.status).to eq(200)
  end

  it "doesn't rollback rate limits for unauthenticated admin api requests" do
    MockRateLimiter
      .expects(:performed!)
      .with(
        nil,
        "global_limit_60_192.0.2.1",
        200,
        60,
        global: true,
        error_code: "ip_60_secs_limit",
        aggressive: true,
      )
      .once
    MockRateLimiter
      .expects(:performed!)
      .with(
        nil,
        "global_limit_10_192.0.2.1",
        50,
        10,
        global: true,
        error_code: "ip_10_secs_limit",
        aggressive: true,
      )
      .once

    get(
      "/admin/backups.json",
      headers: {
        "Api-Key" => "bogus key",
        "Api-Username" => api_username,
      },
      env: {
        REMOTE_ADDR: "192.0.2.1",
      },
    )

    expect(response.status).to eq(404)
  end
end
