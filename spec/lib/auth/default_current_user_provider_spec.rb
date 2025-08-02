# frozen_string_literal: true

RSpec.describe Auth::DefaultCurrentUserProvider do
  # careful using fab! here is can lead to an erratic test
  # we want a distinct user object per test so last_seen_at is
  # handled correctly
  let(:user) { Fabricate(:user) }

  class TestProvider < Auth::DefaultCurrentUserProvider
    attr_reader :env

    def cookie_jar
      @cookie_jar ||= ActionDispatch::Request.new(env).cookie_jar
    end
  end

  def provider(url, opts = nil)
    opts ||= { method: "GET" }
    env = create_request_env(path: url).merge(opts)
    TestProvider.new(env)
  end

  def get_cookie_info(cookie_jar, name)
    response = ActionDispatch::Response.new
    cookie_jar.always_write_cookie = true
    cookie_jar.write(response)

    header = response.headers["Set-Cookie"]
    return if header.nil?

    info = {}

    line = header.split("\n").find { |l| l.start_with?("#{name}=") }
    parts = line.split(";").map(&:strip)

    info[:value] = parts.shift.split("=")[1]
    parts.each do |p|
      key, value = p.split("=")
      info[key.downcase.to_sym] = value || true
    end

    info
  end

  it "can be used to pretend that a user doesn't exist" do
    provider = TestProvider.new(create_request_env(path: "/"))
    expect(provider.current_user).to eq(nil)
  end

  describe "server header api" do
    it "raises for a revoked key" do
      api_key = ApiKey.create!
      params = { "HTTP_API_USERNAME" => user.username.downcase, "HTTP_API_KEY" => api_key.key }
      expect(provider("/", params).current_user.id).to eq(user.id)

      api_key.reload.update(revoked_at: Time.zone.now, last_used_at: nil)
      expect(api_key.reload.last_used_at).to eq(nil)
      params = { "HTTP_API_USERNAME" => user.username.downcase, "HTTP_API_KEY" => api_key.key }

      expect { provider("/", params).current_user }.to raise_error(Discourse::InvalidAccess)

      api_key.reload
      expect(api_key.last_used_at).to eq(nil)
    end

    it "raises errors for incorrect api_key" do
      params = { "HTTP_API_KEY" => "INCORRECT" }
      expect { provider("/", params).current_user }.to raise_error(
        Discourse::InvalidAccess,
        /API username or key is invalid/,
      )
    end

    it "finds a user for a correct per-user api key" do
      api_key = ApiKey.create!(user_id: user.id, created_by_id: -1)
      params = { "HTTP_API_KEY" => api_key.key }

      good_provider = provider("/", params)

      expect do expect(good_provider.current_user.id).to eq(user.id) end.to change {
        api_key.reload.last_used_at
      }

      expect(good_provider.is_api?).to eq(true)
      expect(good_provider.is_user_api?).to eq(false)
      expect(good_provider.should_update_last_seen?).to eq(false)

      user.update_columns(active: false)

      expect { provider("/", params).current_user }.to raise_error(Discourse::InvalidAccess)

      user.update_columns(active: true, suspended_till: 1.day.from_now)

      expect { provider("/", params).current_user }.to raise_error(Discourse::InvalidAccess)
    end

    it "raises for a user pretending" do
      user2 = Fabricate(:user)
      api_key = ApiKey.create!(user_id: user.id, created_by_id: -1)
      params = { "HTTP_API_KEY" => api_key.key, "HTTP_API_USERNAME" => user2.username.downcase }

      expect { provider("/", params).current_user }.to raise_error(Discourse::InvalidAccess)
    end

    it "raises for a user with a mismatching ip" do
      api_key = ApiKey.create!(user_id: user.id, created_by_id: -1, allowed_ips: ["10.0.0.0/24"])
      params = {
        "HTTP_API_KEY" => api_key.key,
        "HTTP_API_USERNAME" => user.username.downcase,
        "REMOTE_ADDR" => "10.1.0.1",
      }

      expect { provider("/", params).current_user }.to raise_error(Discourse::InvalidAccess)
    end

    it "allows a user with a matching ip" do
      api_key = ApiKey.create!(user_id: user.id, created_by_id: -1, allowed_ips: ["100.0.0.0/24"])
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
        "HTTP_X_FORWARDED_FOR" => "10.1.1.1, 100.0.0.22",
      }

      found_user = provider("/", params).current_user
      expect(found_user.id).to eq(user.id)
    end

    it "finds a user for a correct system api key" do
      api_key = ApiKey.create!(created_by_id: -1)
      params = { "HTTP_API_KEY" => api_key.key, "HTTP_API_USERNAME" => user.username.downcase }
      expect(provider("/", params).current_user.id).to eq(user.id)
    end

    it "raises for a mismatched api_key header and param username" do
      api_key = ApiKey.create!(created_by_id: -1)
      params = { "HTTP_API_KEY" => api_key.key }
      expect {
        provider("/?api_username=#{user.username.downcase}", params).current_user
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "finds a user for a correct system api key with external id" do
      api_key = ApiKey.create!(created_by_id: -1)
      SingleSignOnRecord.create(user_id: user.id, external_id: "abc", last_payload: "")
      params = { "HTTP_API_KEY" => api_key.key, "HTTP_API_USER_EXTERNAL_ID" => "abc" }
      expect(provider("/", params).current_user.id).to eq(user.id)
    end

    it "raises for a mismatched api_key header and param external id" do
      api_key = ApiKey.create!(created_by_id: -1)
      SingleSignOnRecord.create(user_id: user.id, external_id: "abc", last_payload: "")
      params = { "HTTP_API_KEY" => api_key.key }
      expect { provider("/?api_user_external_id=abc", params).current_user }.to raise_error(
        Discourse::InvalidAccess,
      )
    end

    it "finds a user for a correct system api key with id" do
      api_key = ApiKey.create!(created_by_id: -1)
      params = { "HTTP_API_KEY" => api_key.key, "HTTP_API_USER_ID" => user.id }
      expect(provider("/", params).current_user.id).to eq(user.id)
    end

    it "raises for a mismatched api_key header and param user id" do
      api_key = ApiKey.create!(created_by_id: -1)
      params = { "HTTP_API_KEY" => api_key.key }
      expect { provider("/?api_user_id=#{user.id}", params).current_user }.to raise_error(
        Discourse::InvalidAccess,
      )
    end

    describe "when readonly mode is enabled due to postgres" do
      before { Discourse.enable_readonly_mode(Discourse::PG_READONLY_MODE_KEY) }

      after { Discourse.disable_readonly_mode(Discourse::PG_READONLY_MODE_KEY) }

      it "should not update ApiKey#last_used_at" do
        api_key = ApiKey.create!(user_id: user.id, created_by_id: -1)
        params = { "HTTP_API_KEY" => api_key.key }

        good_provider = provider("/", params)

        expect do expect(good_provider.current_user.id).to eq(user.id) end.to_not change {
          api_key.reload.last_used_at
        }
      end
    end

    context "with rate limiting" do
      before { RateLimiter.enable }

      it "rate limits admin api requests" do
        global_setting :max_admin_api_reqs_per_minute, 3

        freeze_time
        RateLimiter.new(nil, "admin_api_min", 3, 60).clear!

        api_key = ApiKey.create!(created_by_id: -1)
        params = { "HTTP_API_KEY" => api_key.key, "HTTP_API_USERNAME" => user.username.downcase }
        system_params = params.merge("HTTP_API_USERNAME" => "system")

        provider("/", params).current_user
        provider("/", system_params).current_user
        provider("/", params).current_user

        expect do provider("/", system_params).current_user end.to raise_error(
          RateLimiter::LimitExceeded,
        )

        freeze_time 59.seconds.from_now

        expect do provider("/", system_params).current_user end.to raise_error(
          RateLimiter::LimitExceeded,
        )

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
    let(:cookie) do
      new_provider = provider("/")
      new_provider.log_on_user(user, {}, new_provider.cookie_jar)
      CGI.escape(new_provider.cookie_jar["_t"])
    end

    before do
      @orig = freeze_time
      user.clear_last_seen_cache!(@orig)
    end

    after { user.clear_last_seen_cache!(@orig) }

    it "should not update last seen for suspended users" do
      provider2 = provider("/", "HTTP_COOKIE" => "_t=#{cookie}")
      u = provider2.current_user
      u.reload
      expect(u.last_seen_at).to eq_time(Time.zone.now)

      freeze_time 20.minutes.from_now

      u.last_seen_at = nil
      u.suspended_till = 1.year.from_now
      u.save!

      u.clear_last_seen_cache!

      provider2 = provider("/", "HTTP_COOKIE" => "_t=#{cookie}")
      expect(provider2.current_user).to eq(nil)

      u.reload
      expect(u.last_seen_at).to eq(nil)
    end

    describe "when readonly mode is enabled due to postgres" do
      before { Discourse.enable_readonly_mode(Discourse::PG_READONLY_MODE_KEY) }

      after { Discourse.disable_readonly_mode(Discourse::PG_READONLY_MODE_KEY) }

      it "should not update User#last_seen_at" do
        provider2 = provider("/", "HTTP_COOKIE" => "_t=#{cookie}")
        u = provider2.current_user
        u.reload
        expect(u.last_seen_at).to eq(nil)
      end
    end

    it "should not cache an invalid user when Rails hasn't set `path_parameters` on the request yet" do
      SiteSetting.login_required = true
      user = Fabricate(:user)
      api_key = ApiKey.create!(user_id: user.id, created_by_id: Discourse.system_user)
      url = "/latest.rss?api_key=#{api_key.key}&api_username=#{user.username_lower}"
      env = { ActionDispatch::Http::Parameters::PARAMETERS_KEY => nil }

      provider = provider(url, env)
      env = provider.env

      expect(env[ActionDispatch::Http::Parameters::PARAMETERS_KEY]).to be_nil
      expect(provider.env[Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY]).to be_nil

      u = provider.current_user

      expect(u).to eq(user)
      expect(env[ActionDispatch::Http::Parameters::PARAMETERS_KEY]).to be_blank
      expect(provider.env[Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY]).to eq(u)
    end
  end

  it "should update last seen for non ajax" do
    expect(provider("/topic/anything/goes", method: "POST").should_update_last_seen?).to eq(true)
    expect(provider("/topic/anything/goes", method: "GET").should_update_last_seen?).to eq(true)
  end

  it "should update ajax reqs with discourse visible" do
    expect(
      provider(
        "/topic/anything/goes",
        :method => "POST",
        "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
        "HTTP_DISCOURSE_PRESENT" => "true",
      ).should_update_last_seen?,
    ).to eq(true)
  end

  it "should not update last seen for ajax calls without Discourse-Present header" do
    expect(
      provider(
        "/topic/anything/goes",
        :method => "POST",
        "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
      ).should_update_last_seen?,
    ).to eq(false)
  end

  it "should update last seen for API calls with Discourse-Present header" do
    api_key = ApiKey.create!(user_id: user.id, created_by_id: -1)
    params = {
      :method => "POST",
      "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
      "HTTP_API_KEY" => api_key.key,
    }

    expect(provider("/topic/anything/goes", params).should_update_last_seen?).to eq(false)
    expect(
      provider(
        "/topic/anything/goes",
        params.merge("HTTP_DISCOURSE_PRESENT" => "true"),
      ).should_update_last_seen?,
    ).to eq(true)
  end

  it "supports non persistent sessions" do
    SiteSetting.persistent_sessions = false

    @provider = provider("/")
    @provider.log_on_user(user, {}, @provider.cookie_jar)

    cookie_info = get_cookie_info(@provider.cookie_jar, "_t")
    expect(cookie_info[:expires]).to eq(nil)
  end

  it "v0 of auth cookie is still acceptable" do
    token = UserAuthToken.generate!(user_id: user.id).unhashed_auth_token
    ip = "10.0.0.1"
    env = { "HTTP_COOKIE" => "_t=#{token}", "REMOTE_ADDR" => ip }
    expect(provider("/", env).current_user.id).to eq(user.id)
  end

  it "correctly rotates tokens" do
    SiteSetting.maximum_session_age = 3
    @provider = provider("/")
    @provider.log_on_user(user, {}, @provider.cookie_jar)

    cookie = @provider.cookie_jar["_t"]
    unhashed_token = decrypt_auth_cookie(cookie)[:token]
    cookie = CGI.escape(cookie)

    token = UserAuthToken.find_by(user_id: user.id)

    expect(token.auth_token_seen).to eq(false)
    expect(token.auth_token).not_to eq(unhashed_token)
    expect(token.auth_token).to eq(UserAuthToken.hash_token(unhashed_token))

    # at this point we are going to try to rotate token
    freeze_time 20.minutes.from_now

    provider2 = provider("/", "HTTP_COOKIE" => "_t=#{cookie}")
    provider2.current_user

    token.reload
    expect(token.auth_token_seen).to eq(true)

    provider2.refresh_session(user, {}, provider2.cookie_jar)
    expect(decrypt_auth_cookie(provider2.cookie_jar["_t"])[:token]).not_to eq(unhashed_token)
    expect(decrypt_auth_cookie(provider2.cookie_jar["_t"])[:token].size).to eq(32)

    token.reload
    expect(token.auth_token_seen).to eq(false)

    freeze_time 21.minutes.from_now

    old_token = token.prev_auth_token
    unverified_token = token.auth_token

    # old token should still work
    provider2 = provider("/", "HTTP_COOKIE" => "_t=#{cookie}")
    expect(provider2.current_user.id).to eq(user.id)

    provider2.refresh_session(user, {}, provider2.cookie_jar)

    token.reload

    # because this should cause a rotation since we can safely
    # assume it never reached the client
    expect(token.prev_auth_token).to eq(old_token)
    expect(token.auth_token).not_to eq(unverified_token)
  end

  describe "events" do
    before do
      @refreshes = 0

      @increase_refreshes = ->(user) { @refreshes += 1 }
      DiscourseEvent.on(:user_session_refreshed, &@increase_refreshes)
    end

    after { DiscourseEvent.off(:user_session_refreshed, &@increase_refreshes) }

    it "fires event when updating last seen" do
      @provider = provider("/")
      @provider.log_on_user(user, {}, @provider.cookie_jar)
      cookie = @provider.cookie_jar["_t"]
      unhashed_token = decrypt_auth_cookie(cookie)[:token]
      cookie = CGI.escape(cookie)
      freeze_time 20.minutes.from_now
      provider2 = provider("/", "HTTP_COOKIE" => "_t=#{cookie}")
      provider2.refresh_session(user, {}, provider2.cookie_jar)
      expect(@refreshes).to eq(1)
    end

    it "does not fire an event when last seen does not update" do
      @provider = provider("/")
      @provider.log_on_user(user, {}, @provider.cookie_jar)
      cookie = @provider.cookie_jar["_t"]
      unhashed_token = decrypt_auth_cookie(cookie)[:token]
      cookie = CGI.escape(cookie)
      freeze_time 2.minutes.from_now
      provider2 = provider("/", "HTTP_COOKIE" => "_t=#{cookie}")
      provider2.refresh_session(user, {}, provider2.cookie_jar)
      expect(@refreshes).to eq(0)
    end
  end

  describe "rate limiting" do
    before { RateLimiter.enable }

    it "can only try 10 bad cookies a minute" do
      token = UserAuthToken.generate!(user_id: user.id)
      cookie =
        create_auth_cookie(
          token: token.unhashed_auth_token,
          user_id: user.id,
          trust_level: user.trust_level,
          issued_at: 5.minutes.ago,
        )

      @provider = provider("/")
      @provider.log_on_user(user, {}, @provider.cookie_jar)

      RateLimiter.new(nil, "cookie_auth_10.0.0.1", 10, 60).clear!
      RateLimiter.new(nil, "cookie_auth_10.0.0.2", 10, 60).clear!

      ip = "10.0.0.1"
      bad_cookie =
        create_auth_cookie(
          token: SecureRandom.hex,
          user_id: user.id,
          trust_level: user.trust_level,
          issued_at: 5.minutes.ago,
        )

      env = { "HTTP_COOKIE" => "_t=#{bad_cookie}", "REMOTE_ADDR" => ip }

      10.times { provider("/", env).current_user }

      expect { provider("/", env).current_user }.to raise_error(Discourse::InvalidAccess)

      expect {
        env["HTTP_COOKIE"] = "_t=#{cookie}"
        provider("/", env).current_user
      }.to raise_error(Discourse::InvalidAccess)

      env["REMOTE_ADDR"] = "10.0.0.2"

      expect { provider("/", env).current_user }.not_to raise_error
    end
  end

  it "correctly removes invalid cookies" do
    bad_cookie =
      create_auth_cookie(
        token: SecureRandom.hex,
        user_id: 1,
        trust_level: 4,
        issued_at: 5.minutes.ago,
      )
    @provider = provider("/")
    @provider.cookie_jar["_t"] = bad_cookie
    @provider.refresh_session(nil, {}, @provider.cookie_jar)
    expect(@provider.cookie_jar.key?("_t")).to eq(false)
  end

  it "logging on user always creates a new token" do
    @provider = provider("/")
    @provider.log_on_user(user, {}, @provider.cookie_jar)
    @provider2 = provider("/")
    @provider2.log_on_user(user, {}, @provider2.cookie_jar)

    expect(UserAuthToken.where(user_id: user.id).count).to eq(2)
  end

  it "cleans up old sessions when a user logs in" do
    yesterday = 1.day.ago

    UserAuthToken.insert_all(
      (1..(UserAuthToken::MAX_SESSION_COUNT + 2)).to_a.map do |i|
        {
          user_id: user.id,
          created_at: yesterday + i.seconds,
          updated_at: yesterday + i.seconds,
          rotated_at: yesterday + i.seconds,
          prev_auth_token: "abc#{i}",
          auth_token: "abc#{i}",
        }
      end,
    )

    # Check the oldest 3 still exist
    expect(UserAuthToken.where(auth_token: (1..3).map { |i| "abc#{i}" }).count).to eq(3)

    # On next login, gets fixed
    @provider = provider("/")
    @provider.log_on_user(user, {}, @provider.cookie_jar)
    expect(UserAuthToken.where(user_id: user.id).count).to eq(UserAuthToken::MAX_SESSION_COUNT)

    # Oldest sessions are 1, 2, 3. They should now be deleted
    expect(UserAuthToken.where(auth_token: (1..3).map { |i| "abc#{i}" }).count).to eq(0)
  end

  it "sets secure, same site lax cookies" do
    SiteSetting.force_https = false
    SiteSetting.same_site_cookies = "Lax"

    @provider = provider("/")
    @provider.log_on_user(user, {}, @provider.cookie_jar)

    cookie_info = get_cookie_info(@provider.cookie_jar, "_t")
    expect(cookie_info[:samesite]).to eq("Lax")
    expect(cookie_info[:httponly]).to eq(true)
    expect(cookie_info.key?(:secure)).to eq(false)

    SiteSetting.force_https = true
    SiteSetting.same_site_cookies = "Disabled"

    @provider = provider("/")
    @provider.log_on_user(user, {}, @provider.cookie_jar)

    cookie_info = get_cookie_info(@provider.cookie_jar, "_t")
    expect(cookie_info[:secure]).to eq(true)
    expect(cookie_info.key?(:same_site)).to eq(false)
  end

  it "correctly expires session" do
    SiteSetting.maximum_session_age = 2
    token = UserAuthToken.generate!(user_id: user.id)
    cookie =
      create_auth_cookie(
        token: token.unhashed_auth_token,
        user_id: user.id,
        trust_level: user.trust_level,
        issued_at: 5.minutes.ago,
      )

    @provider = provider("/")
    @provider.log_on_user(user, {}, @provider.cookie_jar)

    expect(provider("/", "HTTP_COOKIE" => "_t=#{cookie}").current_user.id).to eq(user.id)

    freeze_time 3.hours.from_now
    expect(provider("/", "HTTP_COOKIE" => "_t=#{cookie}").current_user).to eq(nil)
  end

  it "always unstage users" do
    user.update!(staged: true)
    @provider = provider("/")
    @provider.log_on_user(user, {}, @provider.cookie_jar)
    user.reload
    expect(user.staged).to eq(false)
  end

  describe "user api" do
    fab!(:user)

    let(:api_key) do
      Fabricate(
        :user_api_key,
        scopes: ["read"].map { |name| UserApiKeyScope.new(name: name) },
        user: user,
      )
    end

    it "creates a new client if the client id changes" do
      params = {
        "REQUEST_METHOD" => "GET",
        "HTTP_USER_API_KEY" => api_key.key,
        "HTTP_USER_API_CLIENT_ID" => api_key.client.client_id + "1",
      }
      good_provider = provider("/", params)
      expect(good_provider.current_user.id).to eq(user.id)
      expect(UserApiKeyClient.exists?(client_id: api_key.client.client_id + "1")).to eq(true)
    end

    it "allows user API access correctly" do
      params = { "REQUEST_METHOD" => "GET", "HTTP_USER_API_KEY" => api_key.key }

      good_provider = provider("/", params)

      expect do expect(good_provider.current_user.id).to eq(user.id) end.to change {
        api_key.reload.last_used_at
      }

      expect(good_provider.is_api?).to eq(false)
      expect(good_provider.is_user_api?).to eq(true)
      expect(good_provider.should_update_last_seen?).to eq(false)

      expect {
        provider("/", params.merge("REQUEST_METHOD" => "POST")).current_user
      }.to raise_error(Discourse::InvalidAccess)

      user.update_columns(suspended_till: 1.year.from_now)

      expect { provider("/", params).current_user }.to raise_error(Discourse::InvalidAccess)
    end

    describe "when readonly mode is enabled due to postgres" do
      before { Discourse.enable_readonly_mode(Discourse::PG_READONLY_MODE_KEY) }

      after { Discourse.disable_readonly_mode(Discourse::PG_READONLY_MODE_KEY) }

      it "should not update ApiKey#last_used_at" do
        params = { "REQUEST_METHOD" => "GET", "HTTP_USER_API_KEY" => api_key.key }

        good_provider = provider("/", params)

        expect do expect(good_provider.current_user.id).to eq(user.id) end.to_not change {
          api_key.reload.last_used_at
        }
      end
    end

    context "with rate limiting" do
      before { RateLimiter.enable }

      it "rate limits api usage" do
        limiter1 = RateLimiter.new(nil, "user_api_day_#{ApiKey.hash_key(api_key.key)}", 10, 60)
        limiter2 = RateLimiter.new(nil, "user_api_min_#{ApiKey.hash_key(api_key.key)}", 10, 60)
        limiter1.clear!
        limiter2.clear!

        global_setting :max_user_api_reqs_per_day, 3
        global_setting :max_user_api_reqs_per_minute, 4

        params = { "REQUEST_METHOD" => "GET", "HTTP_USER_API_KEY" => api_key.key }

        3.times { provider("/", params).current_user }

        expect { provider("/", params).current_user }.to raise_error(RateLimiter::LimitExceeded)

        global_setting :max_user_api_reqs_per_day, 4
        global_setting :max_user_api_reqs_per_minute, 3

        limiter1.clear!
        limiter2.clear!

        3.times { provider("/", params).current_user }

        expect { provider("/", params).current_user }.to raise_error(RateLimiter::LimitExceeded)
      end
    end
  end

  it "ignores a valid auth cookie that has been tampered with" do
    @provider = provider("/")
    @provider.log_on_user(user, {}, @provider.cookie_jar)

    cookie = @provider.cookie_jar["_t"]
    cookie = swap_2_different_characters(cookie)

    ip = "10.0.0.1"
    env = { "HTTP_COOKIE" => "_t=#{cookie}", "REMOTE_ADDR" => ip }
    expect(provider("/", env).current_user).to eq(nil)
  end

  it "copes with json-serialized auth cookies" do
    # We're switching to :json during the Rails 7 upgrade, but we want a clean revert path
    # back to Rails 6 if needed

    @provider =
      provider(
        "/",
        { # The upcoming default
          ActionDispatch::Cookies::COOKIES_SERIALIZER => :json,
          :method => "GET",
        },
      )
    @provider.log_on_user(user, {}, @provider.cookie_jar)
    cookie = CGI.escape(@provider.cookie_jar["_t"])

    ip = "10.0.0.1"
    env = { "HTTP_COOKIE" => "_t=#{cookie}", "REMOTE_ADDR" => ip }
    provider2 = provider("/", env)
    expect(provider2.current_user).to eq(user)
    expect(provider2.cookie_jar.encrypted["_t"].keys).to include("user_id", "token") # (strings)
  end

  describe "#log_off_user" do
    let(:env) do
      user_provider = provider("/")
      user_provider.log_on_user(user, {}, user_provider.cookie_jar)
      cookie = CGI.escape(user_provider.cookie_jar["_t"])
      create_request_env(path: "/").merge({ :method => "GET", "HTTP_COOKIE" => "_t=#{cookie}" })
    end

    it "should work when the current user was cached by a different provider instance" do
      user_provider = TestProvider.new(env)
      expect(user_provider.current_user).to eq(user)
      expect(UserAuthToken.find_by(user_id: user.id)).to be_present

      user_provider = TestProvider.new(env)
      user_provider.log_off_user({}, user_provider.cookie_jar)
      expect(UserAuthToken.find_by(user_id: user.id)).to be_nil
    end

    it "should trigger user_logged_out event" do
      event_triggered_user = nil
      event_handler = Proc.new { |user| event_triggered_user = user.id }
      DiscourseEvent.on(:user_logged_out, &event_handler)

      user_provider = TestProvider.new(env)
      user_provider.log_off_user({}, user_provider.cookie_jar)
      expect(event_triggered_user).to eq(user.id)

      DiscourseEvent.off(:user_logged_out, &event_handler)
    end
  end

  describe "first admin user" do
    before do
      user.update!(admin: false, email: "blah@test.com")
      Rails.configuration.stubs(:developer_emails).returns(["blah@test.com"])
    end

    it "makes the user into an admin if their email is in DISCOURSE_DEVELOPER_EMAILS" do
      @provider = provider("/")
      @provider.log_on_user(user, {}, @provider.cookie_jar)
      expect(user.reload.admin).to eq(true)
      user2 = Fabricate(:user)
      @provider.log_on_user(user2, {}, @provider.cookie_jar)
      expect(user2.reload.admin).to eq(false)
    end

    it "adds the user to the correct staff/admin auto groups" do
      @provider = provider("/")
      @provider.log_on_user(user, {}, @provider.cookie_jar)
      user.reload
      expect(user.in_any_groups?([Group::AUTO_GROUPS[:staff]])).to eq(true)
      expect(user.in_any_groups?([Group::AUTO_GROUPS[:admins]])).to eq(true)
    end

    it "runs the job to enable bootstrap mode" do
      @provider = provider("/")
      @provider.log_on_user(user, {}, @provider.cookie_jar)
      expect_job_enqueued(job: :enable_bootstrap_mode, args: { user_id: user.id })
    end
  end
end
