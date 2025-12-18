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
  end
end
