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

      it "does not update ApiKey#last_used_at" do
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

    it "authenticates a seen browser token and resolves the user's theme in one query" do
      theme = Fabricate(:theme, user_selectable: true)
      user.user_option.update!(theme_ids: [theme.id])
      # Warm the theme registry independently of loading the current user's preferences.
      user.guardian.allow_themes?([theme.id])
      token = UserAuthToken.generate!(user_id: user.id)
      token.update!(auth_token_seen: true)
      auth_cookie = create_auth_cookie(token: token.unhashed_auth_token, user_id: user.id)
      browser =
        provider(
          "/",
          "HTTP_COOKIE" => "_t=#{auth_cookie}",
          "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
        )
      request = ActionDispatch::Request.new(browser.env)

      queries =
        track_sql_queries do
          current_user = browser.current_user
          expect(current_user).to eq(user)
          expect(
            ThemeResolver.resolve_theme_id(request, current_user.guardian, current_user),
          ).to eq(theme.id)
        end

      expect(queries.size).to eq(1)
    end

    it "records the visit as mobile for a mobile user agent" do
      provider(
        "/",
        "HTTP_COOKIE" => "_t=#{cookie}",
        "HTTP_USER_AGENT" =>
          "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36",
      ).current_user

      expect(user.visit_record_for(Date.current).mobile).to eq(true)
    end

    it "records the visit as desktop for a desktop user agent" do
      provider(
        "/",
        "HTTP_COOKIE" => "_t=#{cookie}",
        "HTTP_USER_AGENT" =>
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
      ).current_user

      expect(user.visit_record_for(Date.current).mobile).to eq(false)
    end

    it "does not update last seen for suspended users" do
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

      it "does not update User#last_seen_at" do
        provider2 = provider("/", "HTTP_COOKIE" => "_t=#{cookie}")
        u = provider2.current_user
        u.reload
        expect(u.last_seen_at).to eq(nil)
      end
    end

    describe "when impersonating another user" do
      it "does not update User#last_seen_at" do
        old_timestamp = 1.week.ago
        user.update!(last_seen_at: old_timestamp)
        User.any_instance.stubs(:is_impersonating).returns(true)

        provider2 = provider("/", "HTTP_COOKIE" => "_t=#{cookie}")
        u = provider2.current_user

        expect(u.reload.last_seen_at).to eq_time(old_timestamp)
      end
    end

    it "does not cache an invalid user before Rails sets the request's path_parameters" do
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

    context "with the shared session key header" do
      let(:token) { UserAuthToken.generate!(user_id: user.id) }
      let(:key) { described_class.store_shared_session_key(token, user) }

      def authenticate(key)
        provider("/", "HTTP_X_SHARED_SESSION_KEY" => key).current_user
      end

      it "remains usable after the browser token rotates" do
        expect(authenticate(key)).to eq(user)
        token.update!(auth_token_seen: true)
        expect(token.rotate!).to eq(true)
        expect(authenticate(key)).to eq(user)
      end

      it "returns nil once the bound user is suspended" do
        expect(authenticate(key)).to eq(user)
        user.update!(suspended_at: Time.zone.now, suspended_till: 1.year.from_now)
        expect(authenticate(key)).to be_nil
      end

      it "returns nil once the bound user is deactivated" do
        expect(authenticate(key)).to eq(user)
        user.update!(active: false)
        expect(authenticate(key)).to be_nil
      end

      it "returns nil once the token expires or is revoked" do
        expect(authenticate(key)).to eq(user)
        token.update!(rotated_at: (SiteSetting.maximum_session_age.hours + 1.hour).ago)
        expect(authenticate(key)).to be_nil
        token.update!(rotated_at: Time.zone.now)
        token.destroy!
        expect(authenticate(key)).to be_nil
      end

      it "does not upgrade an impersonated credential when impersonation expires" do
        admin = Fabricate(:admin)
        admin_token = UserAuthToken.generate!(user_id: admin.id)
        admin_token.update!(
          impersonated_user_id: user.id,
          impersonation_expires_at: 1.hour.from_now,
        )
        impersonated_key = described_class.store_shared_session_key(admin_token, user)
        expect(authenticate(impersonated_key)).to eq(user)

        freeze_time 61.minutes.from_now
        expect(authenticate(impersonated_key)).to be_nil
      end

      it "returns nil when the bound token's user no longer exists" do
        expect(authenticate(key)).to eq(user)
        user.delete
        expect(authenticate(key)).to be_nil
      end

      it "rejects missing or malformed shared keys and bindings" do
        expect(described_class.read_shared_session_key(nil)).to be_nil
        expect(authenticate("v2_invalid")).to be_nil
        Discourse.redis.setex(described_class.shared_session_redis_key(key), 7.days, token.id.to_s)
        expect(authenticate(key)).to be_nil
      end

      it "ignores both legacy namespaces, including formerly rebound credentials" do
        legacy_key = SecureRandom.hex
        Discourse.redis.setex("shared_session_key_#{legacy_key}", 7.days, user.id.to_s)
        Discourse.redis.setex("shared_session_user_auth_token_id:#{legacy_key}", 7.days, token.id)
        expect(authenticate(legacy_key)).to be_nil
      end
    end
  end

  it "updates last seen for non-AJAX requests" do
    expect(provider("/topic/anything/goes", method: "POST").should_update_last_seen?).to eq(true)
    expect(provider("/topic/anything/goes", method: "GET").should_update_last_seen?).to eq(true)
  end

  it "updates last seen for AJAX requests with Discourse visible" do
    expect(
      provider(
        "/topic/anything/goes",
        :method => "POST",
        "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
        "HTTP_DISCOURSE_PRESENT" => "true",
      ).should_update_last_seen?,
    ).to eq(true)
  end

  it "does not update last seen for AJAX requests without the Discourse-Present header" do
    expect(
      provider(
        "/topic/anything/goes",
        :method => "POST",
        "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
      ).should_update_last_seen?,
    ).to eq(false)
  end

  it "updates last seen for API calls with the Discourse-Present header" do
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

  it "rejects excluded staged users before issuing a session" do
    user.update!(staged: true)
    SiteSetting.allowed_email_domains = "allowed.example"
    @provider = provider("/")

    expect { @provider.log_on_user(user, {}, @provider.cookie_jar) }.to raise_error(
      ActiveRecord::RecordInvalid,
    )

    expect(user.reload.staged).to eq(true)
    expect(user.user_auth_tokens).to be_empty
    expect(@provider.cookie_jar["_t"]).to be_nil
  end

  it "allows existing members to log in after their domain is excluded" do
    SiteSetting.allowed_email_domains = "allowed.example"
    @provider = provider("/")
    existing_user = Fabricate(:user, email: "member@allowed.example")
    SiteSetting.allowed_email_domains = "other.example"

    @provider.log_on_user(existing_user, {}, @provider.cookie_jar)

    expect(@provider.cookie_jar["_t"]).to be_present
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

    it "allows unexpired user API keys" do
      api_key.update!(expires_at: 1.minute.from_now)
      params = { "REQUEST_METHOD" => "GET", "HTTP_USER_API_KEY" => api_key.key }

      expect(provider("/", params).current_user.id).to eq(user.id)
    end

    it "does not allow expired user API keys" do
      api_key.update!(expires_at: 1.minute.ago)
      params = { "REQUEST_METHOD" => "GET", "HTTP_USER_API_KEY" => api_key.key }

      expect { provider("/", params).current_user }.to raise_error(Discourse::InvalidAccess)
    end

    describe "when readonly mode is enabled due to postgres" do
      before { Discourse.enable_readonly_mode(Discourse::PG_READONLY_MODE_KEY) }

      after { Discourse.disable_readonly_mode(Discourse::PG_READONLY_MODE_KEY) }

      it "does not update ApiKey#last_used_at" do
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

  describe "html application layout access" do
    let(:env_key) { Auth::DefaultCurrentUserProvider::HTML_LAYOUT_DISALLOWED_ENV }

    def api_key_with_scopes(*scopes)
      ApiKey
        .create!(user_id: user.id, created_by_id: -1)
        .tap do |api_key|
          scopes.each do |resource, action|
            ApiKeyScope.create!(api_key_id: api_key.id, resource:, action:)
          end
        end
    end

    def user_api_key(*scope_names)
      Fabricate(
        :user_api_key,
        user: user,
        scopes: scope_names.map { |name| UserApiKeyScope.new(name:) },
      )
    end

    def api_key_env(api_key)
      { "REQUEST_METHOD" => "GET", "HTTP_API_KEY" => api_key.key }
    end

    def user_api_key_env(api_key)
      { "REQUEST_METHOD" => "GET", "HTTP_USER_API_KEY" => api_key.key }
    end

    it "disallows the application layout for an API key with granular scopes" do
      test_provider = provider("/t/1/posts.json", api_key_env(api_key_with_scopes(%w[topics read])))

      expect(test_provider.current_user.id).to eq(user.id)
      expect(test_provider.env[env_key]).to eq(true)
    end

    it "allows the application layout for an API key without scopes" do
      test_provider = provider("/", api_key_env(api_key_with_scopes))

      expect(test_provider.current_user.id).to eq(user.id)
      expect(test_provider.env[env_key]).to be_nil
    end

    it "allows the application layout for a read-only API key" do
      test_provider = provider("/", api_key_env(api_key_with_scopes(%w[global read])))

      expect(test_provider.current_user.id).to eq(user.id)
      expect(test_provider.env[env_key]).to be_nil
    end

    it "allows the application layout for an API key that includes global read access" do
      test_provider =
        provider("/", api_key_env(api_key_with_scopes(%w[topics read], %w[global read])))

      expect(test_provider.current_user.id).to eq(user.id)
      expect(test_provider.env[env_key]).to be_nil
    end

    it "disallows the application layout for a user API key without the read or write scopes" do
      test_provider =
        provider("/notifications.json", user_api_key_env(user_api_key("notifications")))

      expect(test_provider.current_user.id).to eq(user.id)
      expect(test_provider.env[env_key]).to eq(true)
    end

    it "allows the application layout for a user API key with the read or write scope" do
      %w[read write].each do |scope_name|
        test_provider = provider("/", user_api_key_env(user_api_key(scope_name)))

        expect(test_provider.current_user.id).to eq(user.id)
        expect(test_provider.env[env_key]).to be_nil
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

  describe "#authenticated_session_user" do
    let(:token) { UserAuthToken.generate!(user_id: user.id) }
    let(:cookie) { "_t=#{create_auth_cookie(token: token.unhashed_auth_token, user_id: user.id)}" }

    it "accepts a still-valid previous token, not a token that has rotated out" do
      freeze_time
      session_provider = provider("/", "HTTP_COOKIE" => cookie)
      expect(session_provider.current_user).to eq(user)
      expect(token.rotate!).to eq(true)
      expect(session_provider.authenticated_session_user).to eq(user)

      freeze_time 2.minutes.from_now
      # Acknowledging the new cookie permits the next rotation to drop the old one.
      UserAuthToken.lookup(token.unhashed_auth_token, seen: true)
      expect(token.rotate!).to eq(true)
      expect(session_provider.authenticated_session_user).to be_nil
    end

    it "checks cookie age even when authentication earlier in the request succeeded" do
      freeze_time
      SiteSetting.maximum_session_age = 1
      old_cookie = create_auth_cookie(token: token.unhashed_auth_token, issued_at: 59.minutes.ago)
      session_provider = provider("/", "HTTP_COOKIE" => "_t=#{old_cookie}")
      expect(session_provider.current_user).to eq(user)

      freeze_time 2.minutes.from_now
      expect(session_provider.authenticated_session_user).to be_nil
    end

    it "rejects delegated credentials even alongside a valid cookie" do
      key = Fabricate(:api_key, user: user)
      shared_key = described_class.store_shared_session_key(token, user)

      [
        { "HTTP_API_KEY" => key.key },
        { "HTTP_X_SHARED_SESSION_KEY" => shared_key },
      ].each do |headers|
        session_provider = provider("/", headers.merge("HTTP_COOKIE" => cookie))
        expect(session_provider.current_user).to eq(user)
        expect(session_provider.authenticated_session_user).to be_nil
      end
    end

    it "does not turn an impersonation into an independent session" do
      GlobalSetting.stubs(:allow_impersonation).returns(true)
      admin = Fabricate(:admin)
      token = UserAuthToken.generate!(user_id: admin.id)
      token.update!(impersonated_user_id: user.id, impersonation_expires_at: 15.minutes.from_now)
      cookie = create_auth_cookie(token: token.unhashed_auth_token, user_id: admin.id)
      session_provider = provider("/", "HTTP_COOKIE" => "_t=#{cookie}")

      expect(session_provider.current_user).to eq(user)
      expect(session_provider.authenticated_session_user).to be_nil
    end
  end

  describe "#authenticated_credential_user" do
    it "re-reads a User API key authenticated by another provider instance" do
      key = Fabricate(:user_api_key, user:, scopes: [UserApiKeyScope.new(name: "write")])
      env = create_request_env(path: "/").merge("HTTP_USER_API_KEY" => key.key)
      expect(TestProvider.new(env).current_user).to eq(user)

      credential_provider = TestProvider.new(env)
      expect(credential_provider.authenticated_credential_user).to eq(user)

      key.update!(revoked_at: Time.zone.now)
      expect(credential_provider.authenticated_credential_user).to be_nil
    end

    it "rejects a browser session revoked after authentication" do
      token = UserAuthToken.generate!(user_id: user.id)
      cookie = create_auth_cookie(token: token.unhashed_auth_token, user_id: user.id)
      session_provider = provider("/", "HTTP_COOKIE" => "_t=#{cookie}")
      expect(session_provider.current_user).to eq(user)
      expect(session_provider.authenticated_credential_user).to eq(user)

      token.destroy!
      expect(session_provider.authenticated_credential_user).to be_nil
    end

    it "rejects a cookie that no longer matches its session" do
      token = UserAuthToken.generate!(user_id: user.id)
      cookie = create_auth_cookie(token: token.unhashed_auth_token, user_id: user.id)
      session_provider = provider("/", "HTTP_COOKIE" => "_t=#{cookie}")
      expect(session_provider.current_user).to eq(user)

      token.update_columns(auth_token: "rotated", prev_auth_token: "rotated")
      expect(session_provider.authenticated_credential_user).to be_nil
    end

    it "accepts the impersonated user of a valid impersonation session" do
      GlobalSetting.stubs(:allow_impersonation).returns(true)
      admin = Fabricate(:admin)
      token = UserAuthToken.generate!(user_id: admin.id)
      token.update!(impersonated_user_id: user.id, impersonation_expires_at: 15.minutes.from_now)
      cookie = create_auth_cookie(token: token.unhashed_auth_token, user_id: admin.id)
      session_provider = provider("/", "HTTP_COOKIE" => "_t=#{cookie}")
      expect(session_provider.current_user).to eq(user)

      expect(session_provider.authenticated_credential_user).to eq(user)

      token.update!(impersonation_expires_at: 1.minute.ago)
      expect(session_provider.authenticated_credential_user).to be_nil
    end
  end

  describe "#log_on_user" do
    it "rejects active and historical shadows after master deletion even when anonymous mode is disabled" do
      SiteSetting.allow_anonymous_mode = true
      SiteSetting.anonymous_posting_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
      master = Fabricate(:user, trust_level: TrustLevel[1])
      historical_shadow = AnonymousShadowCreator.get(master)
      historical_shadow.anonymous_user_master.update!(active: false)
      shadow = AnonymousShadowCreator.get(master)

      master.destroy!
      SiteSetting.allow_anonymous_mode = false

      [shadow, historical_shadow].each do |retained_shadow|
        retained_shadow.reload
        expect(retained_shadow.master_user).to be_nil
        user_provider = provider("/")

        expect do
          user_provider.log_on_user(retained_shadow, {}, user_provider.cookie_jar)
        end.to raise_error(Discourse::InvalidAccess)
        expect(retained_shadow.user_auth_tokens).to be_empty
      end
    end
  end

  describe "#log_off_user" do
    let(:env) do
      user_provider = provider("/")
      user_provider.log_on_user(user, {}, user_provider.cookie_jar)
      cookie = CGI.escape(user_provider.cookie_jar["_t"])
      create_request_env(path: "/").merge({ :method => "GET", "HTTP_COOKIE" => "_t=#{cookie}" })
    end

    it "does not let delegated logout act on a browser cookie sent with the request" do
      SiteSetting.log_out_strict = true
      browser_user = Fabricate(:user)
      browser_token = UserAuthToken.generate!(user_id: browser_user.id)
      delegated_token = UserAuthToken.generate!(user_id: user.id)
      shared_key = described_class.store_shared_session_key(delegated_token, user)
      api_key = ApiKey.create!(user_id: user.id, created_by_id: -1)
      [
        { "HTTP_X_SHARED_SESSION_KEY" => shared_key },
        { "HTTP_API_KEY" => api_key.key },
      ].each do |headers|
        session_provider =
          provider("/", headers.merge("HTTP_COOKIE" => "_t=#{browser_token.unhashed_auth_token}"))
        expect(session_provider.current_user).to eq(user)
        request = ActionDispatch::Request.new(session_provider.env)
        expect(Guardian.new(user, request).current_login_id).to be_nil
        session_provider.log_off_user({}, session_provider.cookie_jar)
        expect(UserAuthToken.exists?(browser_token.id)).to be(true)
        expect(UserAuthToken.exists?(delegated_token.id)).to be(true)
      end
    end

    it "logs off a user cached by another provider instance" do
      user_provider = TestProvider.new(env)
      expect(user_provider.current_user).to eq(user)
      expect(UserAuthToken.find_by(user_id: user.id)).to be_present

      user_provider = TestProvider.new(env)
      user_provider.log_off_user({}, user_provider.cookie_jar)
      expect(UserAuthToken.find_by(user_id: user.id)).to be_nil
    end

    it "triggers the user_logged_out event" do
      event_triggered_user = nil
      event_handler = Proc.new { |user| event_triggered_user = user.id }
      DiscourseEvent.on(:user_logged_out, &event_handler)

      user_provider = TestProvider.new(env)
      user_provider.log_off_user({}, user_provider.cookie_jar)
      expect(event_triggered_user).to eq(user.id)

      DiscourseEvent.off(:user_logged_out, &event_handler)
    end

    it "ignores endpoint data from another login on ordinary logout" do
      SiteSetting.log_out_strict = false
      user_provider = TestProvider.new(env)
      expect(user_provider.current_user).to eq(user)
      current_token = user.user_auth_tokens.sole
      Fabricate(:push_subscription, user: user, user_auth_token: current_token)
      other_push =
        Fabricate(
          :bound_push_subscription,
          user: user,
          data: {
            endpoint: "https://push.example.com/other",
            keys: {
              p256dh: "other",
              auth: "other",
            },
          }.to_json,
        )

      user_provider.log_off_user(
        {},
        user_provider.cookie_jar,
        push_subscription: other_push.parsed_data.with_indifferent_access,
      )

      expect(user.push_subscriptions).to contain_exactly(other_push)
    end

    it "clears even legacy push subscriptions on strict logout" do
      SiteSetting.log_out_strict = true
      Fabricate(:push_subscription, user: user)
      Fabricate(:bound_push_subscription, user: user)

      user_provider = TestProvider.new(env)
      user_provider.log_off_user({}, user_provider.cookie_jar)

      expect(user.push_subscriptions).to be_empty
    end

    it "revokes anonymous shadow credentials on strict logout", :aggregate_failures do
      SiteSetting.log_out_strict = true
      SiteSetting.allow_anonymous_mode = true
      SiteSetting.anonymous_posting_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
      master = Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true)
      shadow = AnonymousShadowCreator.get(master)
      shadow_token = UserAuthToken.generate!(user_id: shadow.id)
      shadow_api_key = Fabricate(:user_api_key, user: shadow)

      master_provider = provider("/")
      master_provider.log_on_user(master, {}, master_provider.cookie_jar)
      master_provider.log_off_user({}, master_provider.cookie_jar)

      expect(UserAuthToken.exists?(shadow_token.id)).to eq(false)
      expect(shadow_api_key.reload.revoked_at).to be_present
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

    it "only makes the user into an admin from an IP inside the admin IP allowlist" do
      SiteSetting.use_admin_ip_allowlist = true
      Fabricate(
        :screened_ip_address,
        ip_address: "198.51.100.7",
        action_type: ScreenedIpAddress.actions[:allow_admin],
      )

      outside_provider = provider("/", "REMOTE_ADDR" => "203.0.113.9")
      outside_provider.log_on_user(user, {}, outside_provider.cookie_jar)
      expect(user.reload.admin).to eq(false)

      inside_provider = provider("/", "REMOTE_ADDR" => "198.51.100.7")
      inside_provider.log_on_user(user, {}, inside_provider.cookie_jar)
      expect(user.reload.admin).to eq(true)
    end
  end

  describe "bootstrap first admin" do
    let(:admin) { Fabricate(:admin, last_seen_at: nil) }
    let(:bootstrapped_users) { [] }
    let(:bootstrap_callback) { ->(user) { bootstrapped_users << [user, user.moderator?] } }

    let(:plugin) { Plugin::Instance.new }

    before do
      plugin.enabled_site_setting(:discourse_sample_plugin_enabled)
      SiteSetting.discourse_sample_plugin_enabled = true
      plugin.register_first_admin_bootstrap(&bootstrap_callback)
    end

    after do
      DiscoursePluginRegistry._raw_first_admin_bootstrap.delete_if do |entry|
        entry[:plugin] == plugin
      end
    end

    it "grants moderation and logs the staff action on the singular admin's first login" do
      @provider = provider("/")
      @provider.log_on_user(admin, {}, @provider.cookie_jar)

      expect(admin.reload.moderator).to eq(true)
      log = UserHistory.where(action: UserHistory.actions[:grant_moderation]).last
      expect(log.target_user_id).to eq(admin.id)
      expect(log.acting_user_id).to eq(Discourse.system_user.id)
      expect(bootstrapped_users).to eq([[admin, true]])
    end

    it "skips bootstrap callbacks from disabled plugins" do
      SiteSetting.discourse_sample_plugin_enabled = false

      @provider = provider("/")
      @provider.log_on_user(admin, {}, @provider.cookie_jar)

      expect(admin.reload.moderator).to eq(true)
      expect(bootstrapped_users).to be_empty
    end

    it "is idempotent: a second login does not re-log grant_moderation" do
      @provider = provider("/")
      @provider.log_on_user(admin, {}, @provider.cookie_jar)
      admin.update!(last_seen_at: nil)

      expect {
        @provider = provider("/")
        @provider.log_on_user(admin.reload, {}, @provider.cookie_jar)
      }.to_not change { UserHistory.where(action: UserHistory.actions[:grant_moderation]).count }

      expect(bootstrapped_users).to eq([[admin, true]])
    end

    it "does not grant moderation when another admin already exists" do
      Fabricate(:admin)

      @provider = provider("/")
      @provider.log_on_user(admin, {}, @provider.cookie_jar)

      expect(admin.reload.moderator).to eq(false)
      expect(bootstrapped_users).to be_empty
      expect(UserHistory.where(action: UserHistory.actions[:grant_moderation]).count).to eq(0)
    end

    it "does not grant moderation when the admin has logged in before" do
      admin.update!(last_seen_at: 1.day.ago)

      @provider = provider("/")
      @provider.log_on_user(admin, {}, @provider.cookie_jar)

      expect(admin.reload.moderator).to eq(false)
      expect(bootstrapped_users).to be_empty
    end

    it "does not grant moderation to non-admin users" do
      @provider = provider("/")
      @provider.log_on_user(user, {}, @provider.cookie_jar)

      expect(user.reload.moderator).to eq(false)
      expect(bootstrapped_users).to be_empty
    end
  end
end
