# encoding: UTF-8
# frozen_string_literal: true

RSpec.describe "rate limiter integration" do
  before { RateLimiter.enable }

  it "will rate limit message bus requests once queueing" do
    freeze_time

    global_setting :reject_message_bus_queue_seconds, 0.1

    post "/message-bus/#{SecureRandom.hex}/poll",
         headers: {
           "HTTP_X_REQUEST_START" => "t=#{Time.now.to_f - 0.2}",
         }

    expect(response.status).to eq(429)
    expect(response.headers["Retry-After"].to_i).to be > 29
  end

  it "will not rate limit when all is good" do
    freeze_time

    global_setting :reject_message_bus_queue_seconds, 0.1

    post "/message-bus/#{SecureRandom.hex}/poll",
         headers: {
           "HTTP_X_REQUEST_START" => "t=#{Time.now.to_f - 0.05}",
         }

    expect(response.status).to eq(200)
  end

  it "will clear the token cookie if invalid" do
    name = Auth::DefaultCurrentUserProvider::TOKEN_COOKIE

    # we try 11 times because the rate limit is 10
    11.times do
      cookies[name] = SecureRandom.hex
      get "/categories.json"
      expect(response.cookies.has_key?(name)).to eq(true)
      expect(response.cookies[name]).to be_nil
    end
  end

  it "can cleanly limit requests and sets a Retry-After header" do
    freeze_time

    admin = Fabricate(:admin)
    api_key = Fabricate(:api_key, user: admin)

    global_setting :max_admin_api_reqs_per_minute, 1

    get "/admin/api/keys.json",
        headers: {
          HTTP_API_KEY: api_key.key,
          HTTP_API_USERNAME: admin.username,
        }

    expect(response.status).to eq(200)

    get "/admin/api/keys.json",
        headers: {
          HTTP_API_KEY: api_key.key,
          HTTP_API_USERNAME: admin.username,
        }

    expect(response.status).to eq(429)

    data = response.parsed_body

    expect(response.headers["Retry-After"]).to eq("60")
    expect(data["extras"]["wait_seconds"]).to eq(60)
  end
end
