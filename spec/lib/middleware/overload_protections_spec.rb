# frozen_string_literal: true

RSpec.describe Middleware::OverloadProtections do
  let(:app) { described_class.new(->(env) { [200, {}, ["OK"]] }) }

  describe "#call" do
    it "returns 503 for anonymous users when queue time exceeds threshold" do
      global_setting :reject_anonymous_min_queue_seconds, 1.0

      env =
        create_request_env.merge(
          Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY => 1.1,
        )

      status, _headers, body = app.call(env)

      expect(status).to eq(503)
      expect(body).to eq(["Server is currently experiencing high load. Please try again later."])
    end

    it "returns 503 when user's auth cookie is invalid and queue time exceeds threshold" do
      global_setting :reject_anonymous_min_queue_seconds, 1.0

      env =
        create_request_env.merge(
          Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY => 1.1,
          "HTTP_COOKIE" => "_t=invalid_cookie",
        )

      status, _headers, body = app.call(env)

      expect(status).to eq(503)
      expect(body).to eq(["Server is currently experiencing high load. Please try again later."])
    end

    it "returns 200 for anonymous users when queue time is below threshold" do
      global_setting :reject_anonymous_min_queue_seconds, 2.0

      env =
        create_request_env.merge(
          Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY => 1.5,
        )

      status, _headers, body = app.call(env)

      expect(status).to eq(200)
    end

    it "returns 200 for logged-in users even when queue time exceeds threshold" do
      global_setting :reject_anonymous_min_queue_seconds, 1.0
      cookie = create_auth_cookie(token: SecureRandom.hex)

      env =
        create_request_env.merge(
          Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY => 1.1,
          "HTTP_COOKIE" => "_t=#{cookie}",
        )

      status, _headers, body = app.call(env)

      expect(status).to eq(200)
    end

    it "returns 200 for requests with a valid API key when queue time exceeds threshold" do
      global_setting :reject_anonymous_min_queue_seconds, 1.0
      api_key = Fabricate(:api_key, user: Fabricate(:user))

      env =
        create_request_env(path: "/latest.json").merge(
          Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY => 1.1,
          Auth::DefaultCurrentUserProvider::HEADER_API_KEY => api_key.key,
        )

      status, _headers, _body = app.call(env)

      expect(status).to eq(200)
    end

    it "returns 200 for requests with a valid User API key when queue time exceeds threshold" do
      global_setting :reject_anonymous_min_queue_seconds, 1.0
      user_api_key = Fabricate(:readonly_user_api_key)

      env =
        create_request_env(path: "/latest.json").merge(
          Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY => 1.1,
          Auth::DefaultCurrentUserProvider::USER_API_KEY => user_api_key.key,
        )

      status, _headers, _body = app.call(env)

      expect(status).to eq(200)
    end

    it "returns 503 when API key is invalid and queue time exceeds threshold" do
      global_setting :reject_anonymous_min_queue_seconds, 1.0

      env =
        create_request_env(path: "/latest.json").merge(
          Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY => 1.1,
          Auth::DefaultCurrentUserProvider::HEADER_API_KEY => "invalid_api_key",
        )

      status, _headers, body = app.call(env)

      expect(status).to eq(503)
      expect(body).to eq(["Server is currently experiencing high load. Please try again later."])
    end

    it "returns 503 when User API key is invalid and queue time exceeds threshold" do
      global_setting :reject_anonymous_min_queue_seconds, 1.0

      env =
        create_request_env(path: "/latest.json").merge(
          Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY => 1.1,
          Auth::DefaultCurrentUserProvider::USER_API_KEY => "invalid_user_api_key",
        )

      status, _headers, body = app.call(env)

      expect(status).to eq(503)
      expect(body).to eq(["Server is currently experiencing high load. Please try again later."])
    end

    it "returns 503 when API key has been revoked and queue time exceeds threshold" do
      global_setting :reject_anonymous_min_queue_seconds, 1.0
      api_key = Fabricate(:api_key, user: Fabricate(:user))
      key_value = api_key.key
      api_key.update!(revoked_at: Time.zone.now)

      env =
        create_request_env(path: "/latest.json").merge(
          Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY => 1.1,
          Auth::DefaultCurrentUserProvider::HEADER_API_KEY => key_value,
        )

      status, _headers, body = app.call(env)

      expect(status).to eq(503)
      expect(body).to eq(["Server is currently experiencing high load. Please try again later."])
    end
  end
end
