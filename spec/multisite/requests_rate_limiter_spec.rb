# frozen_string_literal: true

require "rails_helper"

describe "RequestsRateLimiter in multisite", type: :multisite do
  before do
    global_setting :skip_per_ip_rate_limit_trust_level, 2

    RateLimiter.enable

    test_multisite_connection("default") do
      RateLimiter.clear_all!
    end
    test_multisite_connection("second") do
      RateLimiter.clear_all!
    end
    RateLimiter.clear_all_global!
  end

  def create_limiter(user_id: nil, trust_level: nil, env:)
    RequestsRateLimiter.new(
      user_id: user_id,
      trust_level: trust_level,
      request: Rack::Request.new(env)
    )
  end

  shared_examples "ip rate limiters behavior" do |error_code, app_callback|
    it "applies rate limits on an IP address across all sites" do
      limiter = create_limiter(
        env: create_request_env.merge("REMOTE_ADDR" => "123.10.71.4")
      )
      called = { default: 0, second: 0 }
      test_multisite_connection("default") do
        status, = limiter.apply_limits! do
          called[:default] += 1
          app_callback&.call(limiter.request.env)
          [200, {}, ["OK"]]
        end
        expect(status).to eq(200)

        status, headers, = limiter.apply_limits! do
          called[:default] += 1
          app_callback&.call(limiter.request.env)
          [200, {}, ["OK"]]
        end
        expect(status).to eq(429)
        expect(headers["Discourse-Rate-Limit-Error-Code"]).to eq(error_code)
        expect(called[:default]).to eq(1)
      end

      test_multisite_connection("second") do
        status, headers = limiter.apply_limits! do
          called[:second] += 1
          app_callback&.call(limiter.request.env)
          [200, {}, ["OK"]]
        end
        expect(status).to eq(429)
        expect(headers["Discourse-Rate-Limit-Error-Code"]).to eq(error_code)
        expect(called[:second]).to eq(0)
      end
    end
  end

  shared_examples "user id rate limiters behavior" do |error_code, app_callback|
    it "does not leak rate limits for a user id to other sites" do
      limiter = create_limiter(
        user_id: 1,
        trust_level: 2,
        env: create_request_env.merge("REMOTE_ADDR" => "123.10.71.4")
      )
      called = { default: 0, second: 0 }
      test_multisite_connection("default") do
        status, = limiter.apply_limits! do
          called[:default] += 1
          app_callback&.call(limiter.request.env)
          [200, {}, ["OK"]]
        end
        expect(status).to eq(200)

        status, headers, = limiter.apply_limits! do
          called[:default] += 1
          app_callback&.call(limiter.request.env)
          [200, {}, ["OK"]]
        end
        expect(status).to eq(429)
        expect(headers["Discourse-Rate-Limit-Error-Code"]).to eq(error_code)
        expect(called[:default]).to eq(1)
      end

      test_multisite_connection("second") do
        status, = limiter.apply_limits! do
          called[:second] += 1
          app_callback&.call(limiter.request.env)
          [200, {}, ["OK"]]
        end
        expect(status).to eq(200)

        status, headers, = limiter.apply_limits! do
          called[:second] += 1
          app_callback&.call(limiter.request.env)
          [200, {}, ["OK"]]
        end
        expect(status).to eq(429)
        expect(headers["Discourse-Rate-Limit-Error-Code"]).to eq(error_code)
        expect(called[:second]).to eq(1)
      end
    end
  end

  context "10 seconds limiter" do
    before do
      global_setting :max_reqs_per_ip_per_10_seconds, 1
    end

    include_examples "ip rate limiters behavior", "ip_10_secs_limit"
    include_examples "user id rate limiters behavior", "id_10_secs_limit"
  end

  context "60 seconds limiter" do
    before do
      global_setting :max_reqs_per_ip_per_minute, 1
    end

    include_examples "ip rate limiters behavior", "ip_60_secs_limit"
    include_examples "user id rate limiters behavior", "id_60_secs_limit"
  end

  context "assets 10 seconds limiter" do
    before do
      global_setting :max_asset_reqs_per_ip_per_10_seconds, 1
    end

    app_callback = ->(env) { env["DISCOURSE_IS_ASSET_PATH"] = true }
    include_examples "ip rate limiters behavior", "ip_assets_10_secs_limit", app_callback
    include_examples "user id rate limiters behavior", "id_assets_10_secs_limit", app_callback
  end
end
