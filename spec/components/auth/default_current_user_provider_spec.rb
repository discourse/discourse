require 'rails_helper'
require_dependency 'auth/default_current_user_provider'

describe Auth::DefaultCurrentUserProvider do

  class TestProvider < Auth::DefaultCurrentUserProvider
    attr_reader :env
    def initialize(env)
      super(env)
    end
  end

  def provider(url, opts = nil)
    opts ||= { method: "GET" }
    env = Rack::MockRequest.env_for(url, opts)
    TestProvider.new(env)
  end

  it "can be used to pretend that a user doesn't exist" do
    provider = TestProvider.new({})
    expect(provider.current_user).to eq(nil)
  end

  context "server api" do

    it "raises errors for incorrect api_key" do
      expect {
        provider("/?api_key=INCORRECT").current_user
      }.to raise_error(Discourse::InvalidAccess, /API username or key is invalid/)
    end

    it "finds a user for a correct per-user api key" do
      user = Fabricate(:user)
      ApiKey.create!(key: "hello", user_id: user.id, created_by_id: -1)
      good_provider = provider("/?api_key=hello")
      expect(good_provider.current_user.id).to eq(user.id)
      expect(good_provider.is_api?).to eq(true)
      expect(good_provider.is_user_api?).to eq(false)
      expect(good_provider.should_update_last_seen?).to eq(false)

      user.update_columns(active: false)

      expect {
        provider("/?api_key=hello").current_user
      }.to raise_error(Discourse::InvalidAccess)

      user.update_columns(active: true, suspended_till: 1.day.from_now)

      expect {
        provider("/?api_key=hello").current_user
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "raises for a user pretending" do
      user = Fabricate(:user)
      user2 = Fabricate(:user)
      ApiKey.create!(key: "hello", user_id: user.id, created_by_id: -1)

      expect {
        provider("/?api_key=hello&api_username=#{user2.username.downcase}").current_user
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "raises for a user with a mismatching ip" do
      user = Fabricate(:user)
      ApiKey.create!(key: "hello", user_id: user.id, created_by_id: -1, allowed_ips: ['10.0.0.0/24'])

      expect {
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

    it "finds a user for a correct system api key with external id" do
      user = Fabricate(:user)
      ApiKey.create!(key: "hello", created_by_id: -1)
      SingleSignOnRecord.create(user_id: user.id, external_id: "abc", last_payload: '')
      expect(provider("/?api_key=hello&api_user_external_id=abc").current_user.id).to eq(user.id)
    end

    it "finds a user for a correct system api key with id" do
      user = Fabricate(:user)
      ApiKey.create!(key: "hello", created_by_id: -1)
      expect(provider("/?api_key=hello&api_user_id=#{user.id}").current_user.id).to eq(user.id)
    end

    context "rate limiting" do
      before do
        RateLimiter.enable
      end

      after do
        RateLimiter.disable
      end

      it "rate limits api requests per api key" do
        global_setting :max_admin_api_reqs_per_key_per_minute, 3

        freeze_time

        user = Fabricate(:user)
        key = SecureRandom.hex
        api_key = ApiKey.create!(key: key, created_by_id: -1)

        provider("/?api_key=#{key}&api_username=#{user.username.downcase}").current_user
        provider("/?api_key=#{key}&api_username=system").current_user
        provider("/?api_key=#{key}&api_username=#{user.username.downcase}").current_user

        expect do
          provider("/?api_key=#{key}&api_username=system").current_user
        end.to raise_error(RateLimiter::LimitExceeded)

        freeze_time 59.seconds.from_now

        expect do
          provider("/?api_key=#{key}&api_username=system").current_user
        end.to raise_error(RateLimiter::LimitExceeded)

        freeze_time 2.seconds.from_now

        # 1 minute elapsed
        provider("/?api_key=#{key}&api_username=system").current_user

        # should not rake limit a random key
        api_key.destroy
        key = SecureRandom.hex
        ApiKey.create!(key: key, created_by_id: -1)
        provider("/?api_key=#{key}&api_username=#{user.username.downcase}").current_user

      end
    end

  end

  it "should not update last seen for ajax calls without Discourse-Visible header" do
    expect(provider("/topic/anything/goes",
                    :method => "POST",
                    "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest"
          ).should_update_last_seen?).to eq(false)
  end

  describe "#current_user" do
    after do
      $redis.flushall
    end

    it "should not update last seen for suspended users" do
      provider = provider('/')
      user = Fabricate(:user)
      cookies = {}
      provider.log_on_user(user, {}, cookies)
      unhashed_token = cookies["_t"][:value]

      freeze_time

      provider2 = provider("/", "HTTP_COOKIE" => "_t=#{unhashed_token}")
      u = provider2.current_user
      u.reload
      expect(u.last_seen_at).to eq(Time.now)

      freeze_time 20.minutes.from_now

      u.last_seen_at = nil
      u.suspended_till = 1.year.from_now
      u.save!

      $redis.del("user:#{user.id}:#{Time.now.to_date}")
      provider2 = provider("/", "HTTP_COOKIE" => "_t=#{unhashed_token}")
      expect(provider2.current_user).to eq(nil)

      u.reload
      expect(u.last_seen_at).to eq(nil)
    end
  end

  it "should update ajax reqs with discourse visible" do
    expect(provider("/topic/anything/goes",
                    :method => "POST",
                    "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
                    "HTTP_DISCOURSE_VISIBLE" => "true"
          ).should_update_last_seen?).to eq(true)
  end

  it "should update last seen for non ajax" do
    expect(provider("/topic/anything/goes", method: "POST").should_update_last_seen?).to eq(true)
    expect(provider("/topic/anything/goes", method: "GET").should_update_last_seen?).to eq(true)
  end

  it "correctly rotates tokens" do
    SiteSetting.maximum_session_age = 3
    user = Fabricate(:user)
    @provider = provider('/')
    cookies = {}
    @provider.log_on_user(user, {}, cookies)

    unhashed_token = cookies["_t"][:value]

    token = UserAuthToken.find_by(user_id: user.id)

    expect(token.auth_token_seen).to eq(false)
    expect(token.auth_token).not_to eq(unhashed_token)
    expect(token.auth_token).to eq(UserAuthToken.hash_token(unhashed_token))

    # at this point we are going to try to rotate token
    freeze_time 20.minutes.from_now

    provider2 = provider("/", "HTTP_COOKIE" => "_t=#{unhashed_token}")
    provider2.current_user

    token.reload
    expect(token.auth_token_seen).to eq(true)

    cookies = {}
    provider2.refresh_session(user, {}, cookies)
    expect(cookies["_t"][:value]).not_to eq(unhashed_token)

    token.reload
    expect(token.auth_token_seen).to eq(false)

    freeze_time 21.minutes.from_now

    old_token = token.prev_auth_token
    unverified_token = token.auth_token

    # old token should still work
    provider2 = provider("/", "HTTP_COOKIE" => "_t=#{unhashed_token}")
    expect(provider2.current_user.id).to eq(user.id)

    provider2.refresh_session(user, {}, cookies)

    token.reload

    # because this should cause a rotation since we can safely
    # assume it never reached the client
    expect(token.prev_auth_token).to eq(old_token)
    expect(token.auth_token).not_to eq(unverified_token)

  end

  context "rate limiting" do

    before do
      RateLimiter.enable
    end

    after do
      RateLimiter.disable
    end

    it "can only try 10 bad cookies a minute" do
      user = Fabricate(:user)
      token = UserAuthToken.generate!(user_id: user.id)

      provider('/').log_on_user(user, {}, {})

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
        env["HTTP_COOKIE"] = "_t=#{token.unhashed_auth_token}"
        provider("/", env).current_user
      }.to raise_error(Discourse::InvalidAccess)

      env["REMOTE_ADDR"] = "10.0.0.2"

      expect {
        provider('/', env).current_user
      }.not_to raise_error
    end
  end

  it "correctly removes invalid cookies" do
    cookies = { "_t" => SecureRandom.hex }
    provider('/').refresh_session(nil, {}, cookies)
    expect(cookies.key?("_t")).to eq(false)
  end

  it "logging on user always creates a new token" do
    user = Fabricate(:user)

    provider('/').log_on_user(user, {}, {})
    provider('/').log_on_user(user, {}, {})

    expect(UserAuthToken.where(user_id: user.id).count).to eq(2)
  end

  it "sets secure, same site lax cookies" do
    SiteSetting.force_https = false
    SiteSetting.same_site_cookies = "Lax"

    user = Fabricate(:user)
    cookies = {}
    provider('/').log_on_user(user, {}, cookies)

    expect(cookies["_t"][:same_site]).to eq("Lax")
    expect(cookies["_t"][:httponly]).to eq(true)
    expect(cookies["_t"][:secure]).to eq(false)

    SiteSetting.force_https = true
    SiteSetting.same_site_cookies = "Disabled"

    cookies = {}
    provider('/').log_on_user(user, {}, cookies)

    expect(cookies["_t"][:secure]).to eq(true)
    expect(cookies["_t"].key?(:same_site)).to eq(false)
  end

  it "correctly expires session" do
    SiteSetting.maximum_session_age = 2
    user = Fabricate(:user)
    token = UserAuthToken.generate!(user_id: user.id)

    provider('/').log_on_user(user, {}, {})

    expect(provider("/", "HTTP_COOKIE" => "_t=#{token.unhashed_auth_token}").current_user.id).to eq(user.id)

    freeze_time 3.hours.from_now
    expect(provider("/", "HTTP_COOKIE" => "_t=#{token.unhashed_auth_token}").current_user).to eq(nil)
  end

  it "always unstage users" do
    staged_user = Fabricate(:user, staged: true)
    provider("/").log_on_user(staged_user, {}, {})
    staged_user.reload
    expect(staged_user.staged).to eq(false)
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

    it "can clear old duplicate keys correctly" do
      dupe = UserApiKey.create!(
        application_name: 'my app',
        client_id: '12345',
        scopes: ['read'],
        key: SecureRandom.hex,
        user_id: user.id
      )

      params = {
        "REQUEST_METHOD" => "GET",
        "HTTP_USER_API_KEY" => api_key.key,
        "HTTP_USER_API_CLIENT_ID" => dupe.client_id,
      }

      good_provider = provider("/", params)
      expect(good_provider.current_user.id).to eq(user.id)
      expect(UserApiKey.find_by(id: dupe.id)).to eq(nil)
    end

    it "allows user API access correctly" do
      params = {
        "REQUEST_METHOD" => "GET",
        "HTTP_USER_API_KEY" => api_key.key,
      }

      good_provider = provider("/", params)

      expect(good_provider.current_user.id).to eq(user.id)
      expect(good_provider.is_api?).to eq(false)
      expect(good_provider.is_user_api?).to eq(true)
      expect(good_provider.should_update_last_seen?).to eq(false)

      expect {
        provider("/", params.merge("REQUEST_METHOD" => "POST")).current_user
      }.to raise_error(Discourse::InvalidAccess)

      user.update_columns(suspended_till: 1.year.from_now)

      expect {
        provider("/", params).current_user
      }.to raise_error(Discourse::InvalidAccess)

    end

    context "rate limiting" do

      before do
        RateLimiter.enable
      end

      after do
        RateLimiter.disable
      end

      it "rate limits api usage" do
        limiter1 = RateLimiter.new(nil, "user_api_day_#{api_key.key}", 10, 60)
        limiter2 = RateLimiter.new(nil, "user_api_min_#{api_key.key}", 10, 60)
        limiter1.clear!
        limiter2.clear!

        global_setting :max_user_api_reqs_per_day, 3
        global_setting :max_user_api_reqs_per_minute, 4

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

        global_setting :max_user_api_reqs_per_day, 4
        global_setting :max_user_api_reqs_per_minute, 3

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
end
