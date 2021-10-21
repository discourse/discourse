# frozen_string_literal: true

require "rails_helper"

describe RequestsRateLimiter do
  fab!(:user) { Fabricate(:user) }

  def instance(env = {})
    RequestsRateLimiter.new(user, Rack::Request.new(env))
  end

  before do
    RateLimiter.enable
  end

  after do
    RateLimiter.disable
  end

  describe "#skip_global_limits?" do
    it "returns true if rate limit mode is neither block nor warn" do
      global_setting :max_reqs_per_ip_mode, ""
      expect(instance.skip_global_limits?). to eq(true)

      global_setting :max_reqs_per_ip_mode, "nothing"
      expect(instance.skip_global_limits?). to eq(true)
    end

    it "returns false if rate limit mode is either block or warn or both" do
      global_setting :max_reqs_per_ip_mode, "block"
      expect(instance.skip_global_limits?). to eq(false)

      global_setting :max_reqs_per_ip_mode, "warn"
      expect(instance.skip_global_limits?). to eq(false)

      global_setting :max_reqs_per_ip_mode, "warn+block"
      expect(instance.skip_global_limits?). to eq(false)
    end

    it "returns true if the request ip is private and private ips are excluded from rate limits" do
      global_setting :max_reqs_rate_limit_on_private, false
      expect(instance({ "REMOTE_ADDR" => "192.168.1.1" }).skip_global_limits?).to eq(true)
      expect(instance({ "REMOTE_ADDR" => "193.178.1.10" }).skip_global_limits?).to eq(false)
      global_setting :max_reqs_rate_limit_on_private, true
      expect(instance({ "REMOTE_ADDR" => "192.168.1.1" }).skip_global_limits?).to eq(false)
    end

    it "returns true if ip_skipper callback returns true" do
      orig_callback = Middleware::RequestTracker.ip_skipper
      Middleware::RequestTracker.unregister_ip_skipper
      Middleware::RequestTracker.register_ip_skipper do |ip|
        ip == "193.211.211.4"
      end
      expect(instance({ "REMOTE_ADDR" => "103.211.211.4" }).skip_global_limits?).to eq(false)
      expect(instance({ "REMOTE_ADDR" => "193.211.211.4" }).skip_global_limits?).to eq(true)
    ensure
      Middleware::RequestTracker.unregister_ip_skipper
      Middleware::RequestTracker.register_ip_skipper(orig_callback) if orig_callback
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
        .and change { ins.limiter_60_mins.remaining }.by(-1)
        .and change { ins.assets_limiter_10_secs.remaining }.by(0)
    end

    it "rolls back normal rate limiters if the request is an assets request" do
      ins = instance
      expect {
        ins.apply_limits! do
          ins.request.env['DISCOURSE_IS_ASSET_PATH'] = true
        end
      }.to change { ins.limiter_10_secs.remaining }.by(0)
        .and change { ins.limiter_60_mins.remaining }.by(0)
        .and change { ins.assets_limiter_10_secs.remaining }.by(-1)
    end
  end
end
