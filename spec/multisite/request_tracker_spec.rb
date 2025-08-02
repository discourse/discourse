# frozen_string_literal: true

RSpec.describe "RequestTracker in multisite", type: :multisite do
  before do
    global_setting :skip_per_ip_rate_limit_trust_level, 2

    RateLimiter.enable
    RateLimiter.clear_all_global!
  end

  def call(env, &block)
    Middleware::RequestTracker.new(block).call(env)
  end

  def create_env(opts)
    create_request_env.merge(opts)
  end

  shared_examples "ip rate limiters behavior" do |error_code, app_callback|
    it "applies rate limits on an IP address across all sites" do
      called = { default: 0, second: 0 }
      test_multisite_connection("default") do
        env = create_env("REMOTE_ADDR" => "123.10.71.4")
        status, =
          call(env) do
            called[:default] += 1
            app_callback&.call(env)
            [200, {}, ["OK"]]
          end
        expect(status).to eq(200)

        env = create_env("REMOTE_ADDR" => "123.10.71.4")
        status, headers =
          call(env) do
            called[:default] += 1
            app_callback&.call(env)
            [200, {}, ["OK"]]
          end
        expect(status).to eq(429)
        expect(headers["Discourse-Rate-Limit-Error-Code"]).to eq(error_code)
        expect(called[:default]).to eq(1)
      end

      test_multisite_connection("second") do
        env = create_env("REMOTE_ADDR" => "123.10.71.4")
        status, headers =
          call(env) do
            called[:second] += 1
            app_callback&.call(env)
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
      cookie = create_auth_cookie(token: SecureRandom.hex, user_id: 1, trust_level: 2)
      called = { default: 0, second: 0 }
      test_multisite_connection("default") do
        env = create_env("REMOTE_ADDR" => "123.10.71.4", "HTTP_COOKIE" => "_t=#{cookie}")
        status, =
          call(env) do
            called[:default] += 1
            app_callback&.call(env)
            [200, {}, ["OK"]]
          end
        expect(status).to eq(200)

        env = create_env("REMOTE_ADDR" => "123.10.71.4", "HTTP_COOKIE" => "_t=#{cookie}")
        status, headers, =
          call(env) do
            called[:default] += 1
            app_callback&.call(env)
            [200, {}, ["OK"]]
          end
        expect(status).to eq(429)
        expect(headers["Discourse-Rate-Limit-Error-Code"]).to eq(error_code)
        expect(called[:default]).to eq(1)
      end

      test_multisite_connection("second") do
        env = create_env("REMOTE_ADDR" => "123.10.71.4", "HTTP_COOKIE" => "_t=#{cookie}")
        status, =
          call(env) do
            called[:second] += 1
            app_callback&.call(env)
            [200, {}, ["OK"]]
          end
        expect(status).to eq(200)

        env = create_env("REMOTE_ADDR" => "123.10.71.4", "HTTP_COOKIE" => "_t=#{cookie}")
        status, headers, =
          call(env) do
            called[:second] += 1
            app_callback&.call(env)
            [200, {}, ["OK"]]
          end
        expect(status).to eq(429)
        expect(headers["Discourse-Rate-Limit-Error-Code"]).to eq(error_code)
        expect(called[:second]).to eq(1)
      end
    end
  end

  context "with a 10 seconds limiter" do
    before { global_setting :max_reqs_per_ip_per_10_seconds, 1 }

    include_examples "ip rate limiters behavior", "ip_10_secs_limit"
    include_examples "user id rate limiters behavior", "user_10_secs_limit"
  end

  context "with a 60 seconds limiter" do
    before { global_setting :max_reqs_per_ip_per_minute, 1 }

    include_examples "ip rate limiters behavior", "ip_60_secs_limit"
    include_examples "user id rate limiters behavior", "user_60_secs_limit"
  end

  context "with assets 10 seconds limiter" do
    before { global_setting :max_asset_reqs_per_ip_per_10_seconds, 1 }

    app_callback = ->(env) { env["DISCOURSE_IS_ASSET_PATH"] = true }
    include_examples "ip rate limiters behavior", "ip_assets_10_secs_limit", app_callback
    include_examples "user id rate limiters behavior", "user_assets_10_secs_limit", app_callback
  end
end
