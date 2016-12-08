require 'rails_helper'
require_dependency 'auth/default_current_user_provider'

describe Auth::DefaultCurrentUserProvider do

  def provider(url, opts=nil)
    opts ||= {method: "GET"}
    env = Rack::MockRequest.env_for(url, opts)
    Auth::DefaultCurrentUserProvider.new(env)
  end

  it "raises errors for incorrect api_key" do
    expect{
      provider("/?api_key=INCORRECT").current_user
    }.to raise_error(Discourse::InvalidAccess)
  end

  it "finds a user for a correct per-user api key" do
    user = Fabricate(:user)
    ApiKey.create!(key: "hello", user_id: user.id, created_by_id: -1)
    expect(provider("/?api_key=hello").current_user.id).to eq(user.id)
  end

  it "raises for a user pretending" do
    user = Fabricate(:user)
    user2 = Fabricate(:user)
    ApiKey.create!(key: "hello", user_id: user.id, created_by_id: -1)

    expect{
      provider("/?api_key=hello&api_username=#{user2.username.downcase}").current_user
    }.to raise_error(Discourse::InvalidAccess)
  end

  it "raises for a user with a mismatching ip" do
    user = Fabricate(:user)
    ApiKey.create!(key: "hello", user_id: user.id, created_by_id: -1, allowed_ips: ['10.0.0.0/24'])

    expect{
      provider("/?api_key=hello&api_username=#{user.username.downcase}", "REMOTE_ADDR" => "10.1.0.1").current_user
    }.to raise_error(Discourse::InvalidAccess)

  end

  it "allows a user with a matching ip" do
    user = Fabricate(:user)
    ApiKey.create!(key: "hello", user_id: user.id, created_by_id: -1, allowed_ips: ['100.0.0.0/24'])

    found_user = provider("/?api_key=hello&api_username=#{user.username.downcase}",
                          "REMOTE_ADDR" => "100.0.0.22").current_user

    expect(found_user.id).to eq(user.id)


    found_user = provider("/?api_key=hello&api_username=#{user.username.downcase}",
                          "HTTP_X_FORWARDED_FOR" => "10.1.1.1, 100.0.0.22").current_user
    expect(found_user.id).to eq(user.id)

  end

  it "finds a user for a correct system api key" do
    user = Fabricate(:user)
    ApiKey.create!(key: "hello", created_by_id: -1)
    expect(provider("/?api_key=hello&api_username=#{user.username.downcase}").current_user.id).to eq(user.id)
  end

  it "should not update last seen for message bus" do
    expect(provider("/message-bus/anything/goes", method: "POST").should_update_last_seen?).to eq(false)
    expect(provider("/message-bus/anything/goes", method: "GET").should_update_last_seen?).to eq(false)
  end

  it "should update last seen for others" do
    expect(provider("/topic/anything/goes", method: "POST").should_update_last_seen?).to eq(true)
    expect(provider("/topic/anything/goes", method: "GET").should_update_last_seen?).to eq(true)
  end

  it "correctly renews session once an hour" do
    SiteSetting.maximum_session_age = 3
    user = Fabricate(:user)
    provider('/').log_on_user(user, {}, {})

    freeze_time 2.hours.from_now
    cookies = {}
    provider("/", "HTTP_COOKIE" => "_t=#{user.auth_token}").refresh_session(user, {}, cookies)

    expect(user.auth_token_updated_at - Time.now).to eq(0)
  end

  it "can only try 10 bad cookies a minute" do

    user = Fabricate(:user)
    provider('/').log_on_user(user, {}, {})

    RateLimiter.stubs(:disabled?).returns(false)

    RateLimiter.new(nil, "cookie_auth_10.0.0.1", 10, 60).clear!
    RateLimiter.new(nil, "cookie_auth_10.0.0.2", 10, 60).clear!

    ip = "10.0.0.1"
    env = { "HTTP_COOKIE" => "_t=#{SecureRandom.hex}", "REMOTE_ADDR" => ip }

    10.times do
      provider('/', env).current_user
    end

    expect {
      provider('/', env).current_user
    }.to raise_error(Discourse::InvalidAccess)

    expect {
      env["HTTP_COOKIE"] = "_t=#{user.auth_token}"
      provider("/", env).current_user
    }.to raise_error(Discourse::InvalidAccess)

    env["REMOTE_ADDR"] = "10.0.0.2"
    provider('/', env).current_user
  end

  it "correctly removes invalid cookies" do

    cookies = {"_t" => "BAAAD"}
    provider('/').refresh_session(nil, {}, cookies)

    expect(cookies.key?("_t")).to eq(false)
  end

  it "recycles existing auth_token correctly" do
    SiteSetting.maximum_session_age = 3
    user = Fabricate(:user)
    provider('/').log_on_user(user, {}, {})

    original_auth_token = user.auth_token

    freeze_time 2.hours.from_now
    provider('/').log_on_user(user, {}, {})

    user.reload
    expect(user.auth_token).to eq(original_auth_token)

    freeze_time 10.hours.from_now

    provider('/').log_on_user(user, {}, {})
    user.reload
    expect(user.auth_token).not_to eq(original_auth_token)
  end

  it "correctly expires session" do
    SiteSetting.maximum_session_age = 2
    user = Fabricate(:user)
    provider('/').log_on_user(user, {}, {})

    expect(provider("/", "HTTP_COOKIE" => "_t=#{user.auth_token}").current_user.id).to eq(user.id)

    freeze_time 3.hours.from_now
    expect(provider("/", "HTTP_COOKIE" => "_t=#{user.auth_token}").current_user).to eq(nil)
  end

  context "user api" do
    let :user do
      Fabricate(:user)
    end

    let :api_key do
      UserApiKey.create!(
        application_name: 'my app',
        client_id: '1234',
        scopes: ['read'],
        key: SecureRandom.hex,
        user_id: user.id
      )
    end

    it "allows user API access correctly" do
      params = {
        "REQUEST_METHOD" => "GET",
        "HTTP_USER_API_KEY" => api_key.key,
      }

      expect(provider("/", params).current_user.id).to eq(user.id)

      expect {
        provider("/", params.merge({"REQUEST_METHOD" => "POST"})).current_user
      }.to raise_error(Discourse::InvalidAccess)

    end

    it "rate limits api usage" do

      RateLimiter.stubs(:disabled?).returns(false)
      limiter1 = RateLimiter.new(nil, "user_api_day_#{api_key.key}", 10, 60)
      limiter2 = RateLimiter.new(nil, "user_api_min_#{api_key.key}", 10, 60)
      limiter1.clear!
      limiter2.clear!

      SiteSetting.max_user_api_reqs_per_day = 3
      SiteSetting.max_user_api_reqs_per_minute = 4

      params = {
        "REQUEST_METHOD" => "GET",
        "HTTP_USER_API_KEY" => api_key.key,
      }

      3.times do
        provider("/", params).current_user
      end

      expect {
        provider("/", params).current_user
      }.to raise_error(RateLimiter::LimitExceeded)


      SiteSetting.max_user_api_reqs_per_day = 4
      SiteSetting.max_user_api_reqs_per_minute = 3

      limiter1.clear!
      limiter2.clear!

      3.times do
        provider("/", params).current_user
      end

      expect {
        provider("/", params).current_user
      }.to raise_error(RateLimiter::LimitExceeded)

    end
  end
end

