# frozen_string_literal: true

require "rails_helper"

describe RequestsRateLimiter do
  def assert_rate_limit_response(response, expected)
    status, headers, body = response
    expect(status).to eq(429)
    expect(headers["Discourse-Rate-Limit-Error-Code"]).to eq(expected)
    expect(body.first).to include("Error code: #{expected}")
  end

  class TestLogger
    attr_accessor :warnings

    def initialize
      @warnings = 0
    end

    def warn(*args)
      @warnings += 1
    end
  end

  fab!(:user) { Fabricate(:user, trust_level: 2) }

  def instance(env = {}, user = nil)
    RequestsRateLimiter.new(
      user_id: user&.id,
      trust_level: user&.trust_level,
      request: Rack::Request.new(env)
    )
  end

  before do
    @old_logger = Rails.logger
    Rails.logger = TestLogger.new
    RateLimiter.enable
    RateLimiter.clear_all!
    RateLimiter.clear_all_global!
  end

  after do
    Rails.logger = @old_logger
    RateLimiter.disable
  end

  describe "#skip_limits?" do
    it "returns true if rate limit mode is neither block nor warn" do
      global_setting :max_reqs_per_ip_mode, ""
      expect(instance.skip_limits?). to eq(true)

      global_setting :max_reqs_per_ip_mode, "nothing"
      expect(instance.skip_limits?). to eq(true)
    end

    it "returns false if rate limit mode is either block or warn or both" do
      global_setting :max_reqs_per_ip_mode, "block"
      expect(instance.skip_limits?). to eq(false)

      global_setting :max_reqs_per_ip_mode, "warn"
      expect(instance.skip_limits?). to eq(false)

      global_setting :max_reqs_per_ip_mode, "warn+block"
      expect(instance.skip_limits?). to eq(false)
    end

    it "returns true if the request ip is private and private ips are excluded from rate limits" do
      global_setting :max_reqs_rate_limit_on_private, false
      expect(instance({ "REMOTE_ADDR" => "192.168.1.1" }).skip_limits?).to eq(true)
      expect(instance({ "REMOTE_ADDR" => "193.178.1.10" }).skip_limits?).to eq(false)
      global_setting :max_reqs_rate_limit_on_private, true
      expect(instance({ "REMOTE_ADDR" => "192.168.1.1" }).skip_limits?).to eq(false)
    end

    it "returns true if ip_skipper callback returns true" do
      orig_callback = Middleware::RequestTracker.ip_skipper
      Middleware::RequestTracker.unregister_ip_skipper
      Middleware::RequestTracker.register_ip_skipper do |ip|
        ip == "193.211.211.4"
      end
      expect(instance({ "REMOTE_ADDR" => "103.211.211.4" }).skip_limits?).to eq(false)
      expect(instance({ "REMOTE_ADDR" => "193.211.211.4" }).skip_limits?).to eq(true)
    ensure
      Middleware::RequestTracker.unregister_ip_skipper
      Middleware::RequestTracker.register_ip_skipper(orig_callback) if orig_callback
    end
  end

  describe "#limit_on_user_id?" do
    it "returns false if user id is nil" do
      expect(instance.limit_on_user_id?).to eq(false)
    end

    it "returns false if trust_level is nil" do
      expect(instance.limit_on_user_id?).to eq(false)
    end

    it "returns false if the user's trust level is lower than the " \
    "skip_per_ip_rate_limit_trust_level global setting" do
      global_setting :skip_per_ip_rate_limit_trust_level, 2

      user.update!(trust_level: 1)
      expect(instance({}, user).limit_on_user_id?).to eq(false)
    end

    it "returns true if the user's trust level is equal to or higher than " \
    "skip_per_ip_rate_limit_trust_level global setting" do
      global_setting :skip_per_ip_rate_limit_trust_level, 2

      user.update!(trust_level: 2)
      expect(instance({}, user).limit_on_user_id?).to eq(true)

      user.update!(trust_level: 3)
      expect(instance({}, user).limit_on_user_id?).to eq(true)
    end
  end

  describe "#apply_limits!" do
    it "rolls back assets rate limiter if the request is not an assets request" do
      ins = instance
      expect {
        ins.apply_limits! do
          ins.request.env['DISCOURSE_IS_ASSET_PATH'] = false
        end
      }.to change { ins.limiter_10_secs.remaining }.by(-1)
        .and change { ins.limiter_60_secs.remaining }.by(-1)
        .and change { ins.assets_limiter_10_secs.remaining }.by(0)
    end

    it "rolls back normal rate limiters if the request is an assets request" do
      ins = instance
      expect {
        ins.apply_limits! do
          ins.request.env['DISCOURSE_IS_ASSET_PATH'] = true
        end
      }.to change { ins.limiter_10_secs.remaining }.by(0)
        .and change { ins.limiter_60_secs.remaining }.by(0)
        .and change { ins.assets_limiter_10_secs.remaining }.by(-1)
    end

    it "does not yield if a limit is reached and rate limit mode is block" do
      global_setting :max_reqs_per_ip_per_10_seconds, 1
      called = 0
      ins = instance

      # 2nd iteration is rate limited
      2.times do
        ins.apply_limits! do
          called += 1
        end
      end
      expect(called).to eq(1)
      expect(Rails.logger.warnings).to eq(0)
    end

    it "yields if rate limits are skipped" do
      global_setting :max_reqs_per_ip_mode, "none"
      called = 0
      instance.apply_limits! do
        called += 1
      end
      expect(called).to eq(1)
    end

    it "yields if a rate limit is reached and rate limit mode is warn" do
      global_setting :max_reqs_per_ip_mode, "warn"
      global_setting :max_reqs_per_ip_per_10_seconds, 1
      ins = instance
      called = 0
      2.times do
        ins.apply_limits! do
          called += 1
        end
      end
      expect(called).to eq(2)
      expect(Rails.logger.warnings).to eq(1)
    end

    it "does not yield if a rate limit is reached and rate limit mode is warn+block" do
      global_setting :max_reqs_per_ip_mode, "warn+block"
      global_setting :max_reqs_per_ip_per_10_seconds, 1
      ins = instance
      called = 0
      2.times do
        ins.apply_limits! do
          called += 1
        end
      end
      expect(called).to eq(1)
      expect(Rails.logger.warnings).to eq(1)
    end

    it "returns yield results if no rate limit is reached or rate limits are disabled" do
      res = instance.apply_limits! do
        "hello world"
      end
      expect(res).to eq("hello world")

      global_setting :max_reqs_per_ip_mode, "none"
      res = instance.apply_limits! do
        "hello world2"
      end
      expect(res).to eq("hello world2")
    end

    it "returns the right error response when applying per-user per-10-seconds " \
    "rate limits" do
      global_setting :max_reqs_per_ip_per_10_seconds, 1
      global_setting :skip_per_ip_rate_limit_trust_level, 2
      ins = instance({}, user)
      called = 0
      ins.apply_limits! do
        called += 1
      end
      response = ins.apply_limits! do
        called += 1
      end
      expect(called).to eq(1)
      assert_rate_limit_response(response, "id_10_secs_limit")
    end

    it "returns the right error response when applying per-ip per-10-seconds " \
    "rate limits" do
      global_setting :max_reqs_per_ip_per_10_seconds, 1
      global_setting :skip_per_ip_rate_limit_trust_level, 3
      ins = instance({}, user)
      called = 0
      ins.apply_limits! do
        called += 1
      end
      response = ins.apply_limits! do
        called += 1
      end
      expect(called).to eq(1)
      assert_rate_limit_response(response, "ip_10_secs_limit")
    end

    it "returns the right error response when applying per-user per-minute " \
    "rate limits" do
      global_setting :max_reqs_per_ip_per_minute, 1
      global_setting :skip_per_ip_rate_limit_trust_level, 2
      ins = instance({}, user)
      called = 0
      ins.apply_limits! do
        called += 1
      end
      response = ins.apply_limits! do
        called += 1
      end
      expect(called).to eq(1)
      assert_rate_limit_response(response, "id_60_secs_limit")
    end

    it "returns the right error response when applying per-ip per-minute " \
    "rate limits" do
      global_setting :max_reqs_per_ip_per_minute, 1
      global_setting :skip_per_ip_rate_limit_trust_level, 3
      ins = instance({}, user)
      called = 0
      ins.apply_limits! do
        called += 1
      end
      response = ins.apply_limits! do
        called += 1
      end
      expect(called).to eq(1)
      assert_rate_limit_response(response, "ip_60_secs_limit")
    end

    it "returns the right error response when applying assets per-ip " \
    "per-10-seconds rate limits" do
      global_setting :max_asset_reqs_per_ip_per_10_seconds, 1
      global_setting :skip_per_ip_rate_limit_trust_level, 3
      env = {}
      ins = instance(env, user)
      called = 0
      ins.apply_limits! do
        env["DISCOURSE_IS_ASSET_PATH"] = true
        called += 1
      end
      response = ins.apply_limits! do
        env["DISCOURSE_IS_ASSET_PATH"] = true
        called += 1
      end
      expect(called).to eq(1)
      assert_rate_limit_response(response, "ip_assets_10_secs_limit")
    end

    it "returns the right error response when applying assets per-user " \
    "per-10-seconds rate limits" do
      global_setting :max_asset_reqs_per_ip_per_10_seconds, 1
      global_setting :skip_per_ip_rate_limit_trust_level, 2
      env = {}
      ins = instance(env, user)
      called = 0
      ins.apply_limits! do
        env["DISCOURSE_IS_ASSET_PATH"] = true
        called += 1
      end
      response = ins.apply_limits! do
        env["DISCOURSE_IS_ASSET_PATH"] = true
        called += 1
      end
      expect(called).to eq(1)
      assert_rate_limit_response(response, "id_assets_10_secs_limit")
    end
  end
end
