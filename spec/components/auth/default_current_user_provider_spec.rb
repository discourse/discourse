# frozen_string_literal: true

require 'rails_helper'

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
      api_key = ApiKey.create!(user_id: user.id, created_by_id: -1)
      good_provider = provider("/?api_key=#{api_key.key}")
      expect(good_provider.current_user.id).to eq(user.id)
      expect(good_provider.is_api?).to eq(true)
      expect(good_provider.is_user_api?).to eq(false)
      expect(good_provider.should_update_last_seen?).to eq(false)

      user.update_columns(active: false)

      expect {
        provider("/?api_key=#{api_key.key}").current_user
      }.to raise_error(Discourse::InvalidAccess)

      user.update_columns(active: true, suspended_till: 1.day.from_now)

      expect {
        provider("/?api_key=#{api_key.key}").current_user
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "raises for a user pretending" do
      user = Fabricate(:user)
      user2 = Fabricate(:user)
      key = ApiKey.create!(user_id: user.id, created_by_id: -1)

      expect {
        provider("/?api_key=#{key.key}&api_username=#{user2.username.downcase}").current_user
      }.to raise_error(Discourse::InvalidAccess)

      key.reload
      expect(key.last_used_at).to eq(nil)
    end

    it "raises for a revoked key" do
      user = Fabricate(:user)
      key = ApiKey.create!
      expect(
        provider("/?api_key=#{key.key}&api_username=#{user.username.downcase}").current_user.id
      ).to eq(user.id)

      key.reload.update(revoked_at: Time.zone.now, last_used_at: nil)
      expect(key.reload.last_used_at).to eq(nil)

      expect {
        provider("/?api_key=#{key.key}&api_username=#{user.username.downcase}").current_user
      }.to raise_error(Discourse::InvalidAccess)

      key.reload
      expect(key.last_used_at).to eq(nil)
    end

    it "raises for a user with a mismatching ip" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(user_id: user.id, created_by_id: -1, allowed_ips: ['10.0.0.0/24'])

      expect {
        provider("/?api_key=#{api_key.key}&api_username=#{user.username.downcase}", "REMOTE_ADDR" => "10.1.0.1").current_user
      }.to raise_error(Discourse::InvalidAccess)

    end

    it "allows a user with a matching ip" do
      freeze_time

      user = Fabricate(:user)
      key = ApiKey.create!(user_id: user.id, created_by_id: -1, allowed_ips: ['100.0.0.0/24'])

      found_user = provider("/?api_key=#{key.key}&api_username=#{user.username.downcase}",
                            "REMOTE_ADDR" => "100.0.0.22").current_user

      expect(found_user.id).to eq(user.id)

      found_user = provider("/?api_key=#{key.key}&api_username=#{user.username.downcase}",
                            "HTTP_X_FORWARDED_FOR" => "10.1.1.1, 100.0.0.22").current_user
      expect(found_user.id).to eq(user.id)

      key.reload
      expect(key.last_used_at).to eq_time(Time.zone.now)
    end

    it "finds a user for a correct system api key" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(created_by_id: -1)
      expect(provider("/?api_key=#{api_key.key}&api_username=#{user.username.downcase}").current_user.id).to eq(user.id)
    end

    it "raises for a mismatched api_key param and header username" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(created_by_id: -1)
      params = { "HTTP_API_USERNAME" => user.username.downcase }
      expect {
        provider("/?api_key=#{api_key.key}", params).current_user
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "finds a user for a correct system api key with external id" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(created_by_id: -1)
      SingleSignOnRecord.create(user_id: user.id, external_id: "abc", last_payload: '')
      expect(provider("/?api_key=#{api_key.key}&api_user_external_id=abc").current_user.id).to eq(user.id)
    end

    it "raises for a mismatched api_key param and header external id" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(created_by_id: -1)
      SingleSignOnRecord.create(user_id: user.id, external_id: "abc", last_payload: '')
      params = { "HTTP_API_USER_EXTERNAL_ID" => "abc" }
      expect {
        provider("/?api_key=#{api_key.key}", params).current_user
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "finds a user for a correct system api key with id" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(created_by_id: -1)
      expect(provider("/?api_key=#{api_key.key}&api_user_id=#{user.id}").current_user.id).to eq(user.id)
    end

    it "raises for a mismatched api_key param and header user id" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(created_by_id: -1)
      params = { "HTTP_API_USER_ID" => user.id }
      expect {
        provider("/?api_key=#{api_key.key}", params).current_user
      }.to raise_error(Discourse::InvalidAccess)
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
        api_key = ApiKey.create!(created_by_id: -1)
        key = api_key.key

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
        api_key = ApiKey.create!(created_by_id: -1)
        provider("/?api_key=#{api_key.key}&api_username=#{user.username.downcase}").current_user

      end
    end

  end

  context "server header api" do

    it "raises errors for incorrect api_key" do
      params = { "HTTP_API_KEY" => "INCORRECT" }
      expect {
        provider("/", params).current_user
      }.to raise_error(Discourse::InvalidAccess, /API username or key is invalid/)
    end

    it "finds a user for a correct per-user api key" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(user_id: user.id, created_by_id: -1)
      params = { "HTTP_API_KEY" => api_key.key }

      good_provider = provider("/", params)
      expect(good_provider.current_user.id).to eq(user.id)
      expect(good_provider.is_api?).to eq(true)
      expect(good_provider.is_user_api?).to eq(false)
      expect(good_provider.should_update_last_seen?).to eq(false)

      user.update_columns(active: false)

      expect {
        provider("/", params).current_user
      }.to raise_error(Discourse::InvalidAccess)

      user.update_columns(active: true, suspended_till: 1.day.from_now)

      expect {
        provider("/", params).current_user
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "raises for a user pretending" do
      user = Fabricate(:user)
      user2 = Fabricate(:user)
      api_key = ApiKey.create!(user_id: user.id, created_by_id: -1)
      params = { "HTTP_API_KEY" => api_key.key, "HTTP_API_USERNAME" => user2.username.downcase }

      expect {
        provider("/", params).current_user
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "raises for a user with a mismatching ip" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(user_id: user.id, created_by_id: -1, allowed_ips: ['10.0.0.0/24'])
      params = {
        "HTTP_API_KEY" => api_key.key,
        "HTTP_API_USERNAME" => user.username.downcase,
        "REMOTE_ADDR" => "10.1.0.1"
      }

      expect {
        provider("/", params).current_user
      }.to raise_error(Discourse::InvalidAccess)

    end

    it "allows a user with a matching ip" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(user_id: user.id, created_by_id: -1, allowed_ips: ['100.0.0.0/24'])
      params = {
        "HTTP_API_KEY" => api_key.key,
        "HTTP_API_USERNAME" => user.username.downcase,
        "REMOTE_ADDR" => "100.0.0.22",
      }

      found_user = provider("/", params).current_user

      expect(found_user.id).to eq(user.id)

      params = {
        "HTTP_API_KEY" => api_key.key,
        "HTTP_API_USERNAME" => user.username.downcase,
        "HTTP_X_FORWARDED_FOR" => "10.1.1.1, 100.0.0.22"
      }

      found_user = provider("/", params).current_user
      expect(found_user.id).to eq(user.id)

    end

    it "finds a user for a correct system api key" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(created_by_id: -1)
      params = { "HTTP_API_KEY" => api_key.key, "HTTP_API_USERNAME" => user.username.downcase }
      expect(provider("/", params).current_user.id).to eq(user.id)
    end

    it "raises for a mismatched api_key header and param username" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(created_by_id: -1)
      params = { "HTTP_API_KEY" => api_key.key }
      expect {
        provider("/?api_username=#{user.username.downcase}", params).current_user
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "finds a user for a correct system api key with external id" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(created_by_id: -1)
      SingleSignOnRecord.create(user_id: user.id, external_id: "abc", last_payload: '')
      params = { "HTTP_API_KEY" => api_key.key, "HTTP_API_USER_EXTERNAL_ID" => "abc" }
      expect(provider("/", params).current_user.id).to eq(user.id)
    end

    it "raises for a mismatched api_key header and param external id" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(created_by_id: -1)
      SingleSignOnRecord.create(user_id: user.id, external_id: "abc", last_payload: '')
      params = { "HTTP_API_KEY" => api_key.key }
      expect {
        provider("/?api_user_external_id=abc", params).current_user
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "finds a user for a correct system api key with id" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(created_by_id: -1)
      params = { "HTTP_API_KEY" => api_key.key, "HTTP_API_USER_ID" => user.id }
      expect(provider("/", params).current_user.id).to eq(user.id)
    end

    it "raises for a mismatched api_key header and param user id" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(created_by_id: -1)
      params = { "HTTP_API_KEY" => api_key.key }
      expect {
        provider("/?api_user_id=#{user.id}", params).current_user
      }.to raise_error(Discourse::InvalidAccess)
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
        api_key = ApiKey.create!(created_by_id: -1)
        params = { "HTTP_API_KEY" => api_key.key, "HTTP_API_USERNAME" => user.username.downcase }
        system_params = params.merge("HTTP_API_USERNAME" => "system")

        provider("/", params).current_user
        provider("/", system_params).current_user
        provider("/", params).current_user

        expect do
          provider("/", system_params).current_user
        end.to raise_error(RateLimiter::LimitExceeded)

        freeze_time 59.seconds.from_now

        expect do
          provider("/", system_params).current_user
        end.to raise_error(RateLimiter::LimitExceeded)

        freeze_time 2.seconds.from_now

        # 1 minute elapsed
        provider("/", system_params).current_user

        # should not rate limit a random key
        api_key.destroy
        api_key = ApiKey.create!(created_by_id: -1)
        params = { "HTTP_API_KEY" => api_key.key, "HTTP_API_USERNAME" => user.username.downcase }
        provider("/", params).current_user

      end
    end

  end

  describe "#current_user" do
    # careful using fab! here is can lead to an erratic test
    # we want a distinct user object per test so last_seen_at is
    # handled correctly
    let!(:user) { Fabricate(:user) }

    let(:unhashed_token) do
      new_provider = provider('/')
      cookies = {}
      new_provider.log_on_user(user, {}, cookies)
      cookies["_t"][:value]
    end

    after do
      Discourse.redis.flushall
    end

    it "should not update last seen for suspended users" do
      freeze_time

      provider2 = provider("/", "HTTP_COOKIE" => "_t=#{unhashed_token}")
      u = provider2.current_user
      u.reload
      expect(u.last_seen_at).to eq_time(Time.now)

      freeze_time 20.minutes.from_now

      u.last_seen_at = nil
      u.suspended_till = 1.year.from_now
      u.save!

      Discourse.redis.del("user:#{user.id}:#{Time.now.to_date}")
      provider2 = provider("/", "HTTP_COOKIE" => "_t=#{unhashed_token}")
      expect(provider2.current_user).to eq(nil)

      u.reload
      expect(u.last_seen_at).to eq(nil)
    end

    describe "when readonly mode is enabled due to postgres" do
      before do
        Discourse.enable_readonly_mode(Discourse::PG_READONLY_MODE_KEY)
      end

      after do
        Discourse.disable_readonly_mode(Discourse::PG_READONLY_MODE_KEY)
      end

      it "should not update last seen at" do
        provider2 = provider("/", "HTTP_COOKIE" => "_t=#{unhashed_token}")
        u = provider2.current_user
        u.reload
        expect(u.last_seen_at).to eq(nil)
      end
    end
  end

  it "should update last seen for non ajax" do
    expect(provider("/topic/anything/goes", method: "POST").should_update_last_seen?).to eq(true)
    expect(provider("/topic/anything/goes", method: "GET").should_update_last_seen?).to eq(true)
  end

  it "should update ajax reqs with discourse visible" do
    expect(provider("/topic/anything/goes",
                    :method => "POST",
                    "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
                    "HTTP_DISCOURSE_VISIBLE" => "true"
          ).should_update_last_seen?).to eq(true)
  end

  it "should not update last seen for ajax calls without Discourse-Visible header" do
    expect(provider("/topic/anything/goes",
                    :method => "POST",
                    "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest"
          ).should_update_last_seen?).to eq(false)
  end

  it "should update last seen for API calls with Discourse-Visible header" do
    user = Fabricate(:user)
    api_key = ApiKey.create!(user_id: user.id, created_by_id: -1)
    params = { :method => "POST",
               "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
               "HTTP_API_KEY" => api_key.key
              }

    expect(provider("/topic/anything/goes", params).should_update_last_seen?).to eq(false)
    expect(provider("/topic/anything/goes", params.merge("HTTP_DISCOURSE_VISIBLE" => "true")).should_update_last_seen?).to eq(true)
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

  it "cleans up old sessions when a user logs in" do
    user = Fabricate(:user)

    yesterday = 1.day.ago

    UserAuthToken.insert_all((1..(UserAuthToken::MAX_SESSION_COUNT + 2)).to_a.map do |i|
      {
        user_id: user.id,
        created_at: yesterday + i.seconds,
        updated_at: yesterday + i.seconds,
        rotated_at: yesterday + i.seconds,
        prev_auth_token: "abc#{i}",
        auth_token: "abc#{i}"
      }
    end)

    # Check the oldest 3 still exist
    expect(UserAuthToken.where(auth_token: (1..3).map { |i| "abc#{i}" }).count).to eq(3)

    # On next login, gets fixed
    provider('/').log_on_user(user, {}, {})
    expect(UserAuthToken.where(user_id: user.id).count).to eq(UserAuthToken::MAX_SESSION_COUNT)

    # Oldest sessions are 1, 2, 3. They should now be deleted
    expect(UserAuthToken.where(auth_token: (1..3).map { |i| "abc#{i}" }).count).to eq(0)
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
    fab! :user do
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
