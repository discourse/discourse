# frozen_string_literal: true

RSpec.describe Middleware::AnonymousCache do
  let(:middleware) { Middleware::AnonymousCache.new(lambda { |_| [200, {}, []] }) }

  before { Middleware::AnonymousCache.enable_anon_cache }

  def env(opts = {})
    create_request_env(path: opts.delete(:path) || "http://test.com/path?bla=1").merge(opts)
  end

  describe Middleware::AnonymousCache::Helper do
    def new_helper(opts = {})
      Middleware::AnonymousCache::Helper.new(env(opts))
    end

    describe "#cacheable?" do
      it "true by default" do
        expect(new_helper.cacheable?).to eq(true)
      end

      it "is false for non GET" do
        expect(
          new_helper("ANON_CACHE_DURATION" => 10, "REQUEST_METHOD" => "POST").cacheable?,
        ).to eq(false)
      end

      it "is false if it has a valid auth cookie" do
        cookie = create_auth_cookie(token: SecureRandom.hex)
        expect(new_helper("HTTP_COOKIE" => "jack=1; _t=#{cookie}; jill=2").cacheable?).to eq(false)
      end

      it "is true if it has an invalid auth cookie" do
        cookie = create_auth_cookie(token: SecureRandom.hex, issued_at: 5.minutes.ago)
        cookie = swap_2_different_characters(cookie)
        cookie.prepend("%a0%a1") # an invalid byte sequence
        expect(new_helper("HTTP_COOKIE" => "jack=1; _t=#{cookie}; jill=2").cacheable?).to eq(true)
      end

      it "is false for srv/status routes" do
        expect(new_helper("PATH_INFO" => "/srv/status").cacheable?).to eq(false)
      end

      it "is false for API requests using header" do
        expect(new_helper("HTTP_API_KEY" => "abcde").cacheable?).to eq(false)
      end

      it "is false for API requests using parameter" do
        expect(new_helper(path: "/path?api_key=abc").cacheable?).to eq(false)
      end

      it "is false for User API requests using header" do
        expect(new_helper("HTTP_USER_API_KEY" => "abcde").cacheable?).to eq(false)
      end
    end

    describe "per theme cache" do
      it "handles theme keys" do
        theme = Fabricate(:theme, user_selectable: true)

        with_bad_theme_key = new_helper("HTTP_COOKIE" => "theme_ids=abc").cache_key
        with_no_theme_key = new_helper().cache_key

        expect(with_bad_theme_key).to eq(with_no_theme_key)

        with_good_theme_key = new_helper("HTTP_COOKIE" => "theme_ids=#{theme.id}").cache_key

        expect(with_good_theme_key).not_to eq(with_no_theme_key)
      end
    end

    describe "per color scheme cache" do
      it "handles valid color scheme keys only", :aggregate_failures do
        color_scheme = Fabricate(:color_scheme)

        with_no_scheme_key = new_helper.cache_key
        with_bad_scheme_key =
          new_helper(
            "HTTP_COOKIE" => %(color_scheme_id=#{color_scheme.id}"><link rel="modulepreload">),
          ).cache_key
        with_color_scheme_key =
          new_helper("HTTP_COOKIE" => "color_scheme_id=#{color_scheme.id}").cache_key
        with_dark_scheme_key =
          new_helper("HTTP_COOKIE" => "dark_scheme_id=#{color_scheme.id}").cache_key

        expect(with_bad_scheme_key).to eq(with_no_scheme_key)
        expect(with_color_scheme_key).not_to eq(with_no_scheme_key)
        expect(with_dark_scheme_key).not_to eq(with_no_scheme_key)
        expect(with_color_scheme_key).not_to eq(with_dark_scheme_key)
      end
    end

    context "with header or cookie based custom locale" do
      it "handles different languages" do
        # Normally does not check the language header
        french1 = new_helper("HTTP_ACCEPT_LANGUAGE" => "fr").cache_key
        french2 = new_helper("HTTP_ACCEPT_LANGUAGE" => "FR").cache_key
        english = new_helper("HTTP_ACCEPT_LANGUAGE" => SiteSetting.default_locale).cache_key
        none = new_helper.cache_key

        expect(none).to eq(french1)
        expect(none).to eq(french2)
        expect(none).to eq(english)

        SiteSetting.allow_user_locale = true
        SiteSetting.set_locale_from_accept_language_header = true

        french1 = new_helper("HTTP_ACCEPT_LANGUAGE" => "fr").cache_key
        french2 = new_helper("HTTP_ACCEPT_LANGUAGE" => "FR").cache_key
        english = new_helper("HTTP_ACCEPT_LANGUAGE" => SiteSetting.default_locale).cache_key
        none = new_helper.cache_key

        expect(none).to eq(english)
        expect(french1).to eq(french2)
        expect(french1).not_to eq(none)

        SiteSetting.set_locale_from_cookie = true
        expect(new_helper("HTTP_COOKIE" => "locale=es;").cache_key).to include("l=es")
      end

      it "keys on the locale cookie when the language switcher is enabled" do
        SiteSetting.default_locale = "en"
        SiteSetting.allow_user_locale = true
        SiteSetting.set_locale_from_cookie = false
        SiteSetting.content_localization_supported_locales = "es|fr"
        SiteSetting.content_localization_enabled = true
        SiteSetting.content_localization_language_switcher = "all"

        expect(new_helper("HTTP_COOKIE" => "locale=es;").cache_key).to include("l=es")

        # An unsupported locale is not honoured, so it must not fan the cache out either.
        expect(new_helper("HTTP_COOKIE" => "locale=ja;").cache_key).to eq(new_helper.cache_key)
      end

      it "keys on the same locale the request renders in" do
        SiteSetting.default_locale = "en"
        SiteSetting.allow_user_locale = true
        SiteSetting.content_localization_supported_locales = "es"
        SiteSetting.content_localization_enabled = true
        SiteSetting.content_localization_language_switcher = "all"

        env = { "HTTP_COOKIE" => "locale=es;" }
        request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/", env))

        expect(new_helper(env).cache_key).to include("l=#{Discourse.anonymous_locale(request)}")
      end
    end

    it "handles old browsers" do
      SiteSetting.browser_update_user_agents = "my_old_browser"

      key1 = new_helper("HTTP_USER_AGENT" => "my_old_browser").cache_key
      key2 = new_helper("HTTP_USER_AGENT" => "my_new_browser").cache_key
      expect(key1).not_to eq(key2)
    end

    it "handles modern mobile browsers" do
      key1 = new_helper("HTTP_USER_AGENT" => "Safari (iPhone OS 7)").cache_key
      key2 = new_helper("HTTP_USER_AGENT" => "Safari (iPhone OS 16)").cache_key
      expect(key1).not_to eq(key2)
    end

    it "handles user agents with invalid bytes" do
      agent = (+"Evil Googlebot String \xc3\x28").force_encoding("ASCII")
      expect {
        key1 = new_helper("HTTP_USER_AGENT" => agent).cache_key
        key2 =
          new_helper(
            "HTTP_USER_AGENT" => agent.encode("utf-8", invalid: :replace, undef: :replace),
          ).cache_key
        expect(key1).to eq(key2)
      }.not_to raise_error
    end

    it "keys only on the resolved automatic translation preference" do
      regular_key = new_helper.cache_key
      enabled_key =
        new_helper(
          "HTTP_COOKIE" => "#{ContentLocalization::AUTOMATICALLY_TRANSLATE_COOKIE}=true",
        ).cache_key
      disabled_key =
        new_helper(
          "HTTP_COOKIE" => "#{ContentLocalization::AUTOMATICALLY_TRANSLATE_COOKIE}=false",
        ).cache_key

      expect(enabled_key).to eq(regular_key)
      expect(disabled_key).not_to eq(regular_key)
    end

    context "when cached" do
      let!(:helper) { new_helper("ANON_CACHE_DURATION" => 10) }

      let!(:crawler) do
        new_helper(
          "ANON_CACHE_DURATION" => 10,
          "HTTP_USER_AGENT" => "AdsBot-Google (+http://www.google.com/adsbot.html)",
        )
      end

      after do
        helper.clear_cache
        crawler.clear_cache
      end

      before { global_setting :anon_cache_store_threshold, 1 }

      it "compresses body on demand" do
        global_setting :compress_anon_cache, true

        payload = "x" * 1000
        helper.cache([200, { "HELLO" => "WORLD" }, [payload]])

        helper = new_helper("ANON_CACHE_DURATION" => 10)
        expect(helper.cached).to eq(
          [200, { "X-Discourse-Cached" => "true", "HELLO" => "WORLD" }, [payload]],
        )

        # depends on i7z implementation, but lets assume it is stable unless we discover
        # otherwise
        expect(Discourse.redis.get(helper.cache_key_body).length).to eq(16)
      end

      it "handles brotli switching" do
        helper.cache([200, { "HELLO" => "WORLD" }, ["hello ", "my world"]])

        helper = new_helper("ANON_CACHE_DURATION" => 10)
        expect(helper.cached).to eq(
          [200, { "X-Discourse-Cached" => "true", "HELLO" => "WORLD" }, ["hello my world"]],
        )

        helper = new_helper("ANON_CACHE_DURATION" => 10, "HTTP_ACCEPT_ENCODING" => "gz, br")
        expect(helper.cached).to eq(nil)
      end

      it "includes the forced color mode in the cache key" do
        dark_helper =
          new_helper("ANON_CACHE_DURATION" => 10, "HTTP_COOKIE" => "forced_color_mode=dark")
        dark_helper.cache([200, { "HELLO" => "WORLD" }, ["dark mode"]])

        light_helper =
          new_helper("ANON_CACHE_DURATION" => 10, "HTTP_COOKIE" => "forced_color_mode=light")
        expect(light_helper.cached).to eq(nil)

        light_helper.cache([200, { "HELLO" => "WORLD" }, ["light mode"]])

        auto_helper = new_helper("ANON_CACHE_DURATION" => 10)
        expect(auto_helper.cached).to eq(nil)

        auto_helper.cache([200, { "HELLO" => "WORLD" }, ["auto color mode"]])

        unknown_helper =
          new_helper("ANON_CACHE_DURATION" => 10, "HTTP_COOKIE" => "forced_color_mode=blada")
        expect(unknown_helper.cached).to eq(
          [200, { "HELLO" => "WORLD", "X-Discourse-Cached" => "true" }, ["auto color mode"]],
        )

        dark_helper =
          new_helper("ANON_CACHE_DURATION" => 10, "HTTP_COOKIE" => "forced_color_mode=dark")
        light_helper =
          new_helper("ANON_CACHE_DURATION" => 10, "HTTP_COOKIE" => "forced_color_mode=light")
        auto_helper = new_helper("ANON_CACHE_DURATION" => 10)

        expect(dark_helper.cached).to eq(
          [200, { "HELLO" => "WORLD", "X-Discourse-Cached" => "true" }, ["dark mode"]],
        )
        expect(light_helper.cached).to eq(
          [200, { "HELLO" => "WORLD", "X-Discourse-Cached" => "true" }, ["light mode"]],
        )
        expect(auto_helper.cached).to eq(
          [200, { "HELLO" => "WORLD", "X-Discourse-Cached" => "true" }, ["auto color mode"]],
        )
      end

      it "returns cached data for cached requests" do
        helper.is_mobile = true
        expect(helper.cached).to eq(nil)
        helper.cache([200, { "HELLO" => "WORLD" }, ["hello ", "my world"]])

        helper = new_helper("ANON_CACHE_DURATION" => 10)
        helper.is_mobile = true
        expect(helper.cached).to eq(
          [200, { "X-Discourse-Cached" => "true", "HELLO" => "WORLD" }, ["hello my world"]],
        )

        expect(crawler.cached).to eq(nil)
        crawler.cache([200, { "HELLO" => "WORLD" }, ["hello ", "world"]])
        expect(crawler.cached).to eq(
          [200, { "X-Discourse-Cached" => "true", "HELLO" => "WORLD" }, ["hello world"]],
        )
      end
    end
  end

  describe "background request rate limit" do
    it "will rate limit background requests" do
      app = Middleware::AnonymousCache.new(lambda { |env| [200, {}, ["ok"]] })

      global_setting :background_requests_max_queue_length, "0.5"

      cookie = create_auth_cookie(token: SecureRandom.hex)
      env =
        create_request_env.merge(
          "HTTP_COOKIE" => "_t=#{cookie}",
          "HOST" => "site.com",
          "REQUEST_METHOD" => "GET",
          "REQUEST_URI" => "/somewhere/rainbow",
          Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY => 2.1,
          "rack.input" => StringIO.new,
        )

      # non background ... long request
      env[Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY] = 2

      status, _ = app.call(env.dup)
      expect(status).to eq(200)

      env["HTTP_DISCOURSE_BACKGROUND"] = "true"

      status, headers, body = app.call(env.dup)
      expect(status).to eq(429)
      expect(headers["content-type"]).to eq("application/json; charset=utf-8")
      json = JSON.parse(body.join)
      expect(json["extras"]["wait_seconds"]).to be > 4.9

      env[Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY] = 0.4

      status, _ = app.call(env.dup)
      expect(status).to eq(200)
    end
  end

  describe "#force_anonymous!" do
    before { RateLimiter.enable }

    it "will revert to anonymous once we reach the limit" do
      is_anon = false

      app =
        Middleware::AnonymousCache.new(
          lambda do |env|
            is_anon = env["HTTP_COOKIE"].nil? && env["HTTP_DISCOURSE_LOGGED_IN"].nil?
            [200, {}, ["ok"]]
          end,
        )

      global_setting :force_anonymous_min_per_10_seconds, 2
      global_setting :force_anonymous_min_queue_seconds, 1

      cookie = create_auth_cookie(token: SecureRandom.hex)
      env =
        create_request_env.merge(
          "HTTP_COOKIE" => "_t=#{cookie}",
          "HTTP_DISCOURSE_LOGGED_IN" => "true",
          "HOST" => "site.com",
          "REQUEST_METHOD" => "GET",
          "REQUEST_URI" => "/somewhere/rainbow",
          Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY => 2.1,
          "rack.input" => StringIO.new,
        )

      is_anon = false
      app.call(env.dup)
      expect(is_anon).to eq(false)

      is_anon = false
      app.call(env.dup)
      expect(is_anon).to eq(false)

      is_anon = false
      app.call(env.dup)
      expect(is_anon).to eq(true)

      is_anon = false
      _status, headers, _body = app.call(env.dup)
      expect(is_anon).to eq(true)
      expect(headers["Set-Cookie"]).to eq("dosp=1; Path=/")

      # tricky change, a 50ms delay still will trigger protection
      # once it is tripped

      env[Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY] = 0.05
      is_anon = false

      app.call(env.dup)
      expect(is_anon).to eq(true)

      is_anon = false
      env[Middleware::ProcessingRequest::REQUEST_QUEUE_SECONDS_ENV_KEY] = 0.01

      app.call(env.dup)
      expect(is_anon).to eq(false)
    end
  end

  describe "invalid request payload" do
    it "returns 413 for GET request with payload" do
      status, headers, _ =
        middleware.call(
          env.tap do |environment|
            environment[Rack::RACK_INPUT].write("test")
            environment[Rack::RACK_INPUT].rewind
          end,
        )

      expect(status).to eq(413)
      expect(headers["Cache-Control"]).to eq("private, max-age=0, must-revalidate")
    end
  end

  describe "crawler blocking" do
    let :non_crawler do
      {
        "HTTP_USER_AGENT" =>
          "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36",
      }
    end

    def get(path, options)
      @env =
        env(
          { "REQUEST_URI" => path, "PATH_INFO" => path, "REQUEST_PATH" => path }.merge(
            options[:headers],
          ),
        )
      @status, @response_header, @response = middleware.call(@env)
    end

    it "applies allowed_crawler_user_agents correctly" do
      SiteSetting.allowed_crawler_user_agents = "Googlebot"

      get "/", headers: { "HTTP_USER_AGENT" => "Googlebot/2.1 (+http://www.google.com/bot.html)" }

      expect(@status).to eq(200)

      get "/",
          headers: {
            "HTTP_USER_AGENT" => "Anotherbot/2.1 (+http://www.notgoogle.com/bot.html)",
          }

      expect(@status).to eq(403)
      expect(@response).to be_an(Array)

      get "/", headers: non_crawler
      expect(@status).to eq(200)
    end

    it "doesn't block api requests" do
      SiteSetting.allowed_crawler_user_agents = "Googlebot"
      api_key = Fabricate(:api_key)

      get "/latest?api_key=#{api_key.key}&api_username=system",
          headers: {
            "QUERY_STRING" => "api_key=#{api_key.key}&api_username=system",
          }
      expect(@status).to eq(200)

      get "/latest", headers: { "HTTP_API_KEY" => api_key.key, "HTTP_API_USERNAME" => "system" }
      expect(@status).to eq(200)
    end

    it "applies blocked_crawler_user_agents correctly" do
      SiteSetting.blocked_crawler_user_agents = "Googlebot"

      get "/", headers: non_crawler
      expect(@status).to eq(200)

      get "/", headers: { "HTTP_USER_AGENT" => "Googlebot/2.1 (+http://www.google.com/bot.html)" }

      expect(@status).to eq(403)

      expect {
        get "/",
            headers: {
              "HTTP_USER_AGENT" => (+"Evil Googlebot String \xc3\x28").force_encoding("ASCII"),
            }

        expect(@status).to eq(403)
      }.not_to raise_error

      get "/",
          headers: {
            "HTTP_USER_AGENT" => "Twitterbot/2.1 (+http://www.notgoogle.com/bot.html)",
          }

      expect(@status).to eq(200)
    end

    it "should never block robots.txt" do
      SiteSetting.blocked_crawler_user_agents = "Googlebot"

      get "/robots.txt",
          headers: {
            "HTTP_USER_AGENT" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(@status).to eq(200)
    end

    it "should never block srv/status" do
      SiteSetting.blocked_crawler_user_agents = "Googlebot"

      get "/srv/status",
          headers: {
            "HTTP_USER_AGENT" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(@status).to eq(200)
    end

    it "blocked crawlers shouldn't log page views" do
      SiteSetting.blocked_crawler_user_agents = "Googlebot"

      get "/", headers: { "HTTP_USER_AGENT" => "Googlebot/2.1 (+http://www.google.com/bot.html)" }

      expect(@env["discourse.request_tracker.skip"]).to eq(true)
    end

    it "blocks json requests" do
      SiteSetting.blocked_crawler_user_agents = "Googlebot"

      get "/srv/status.json",
          headers: {
            "HTTP_USER_AGENT" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(@status).to eq(403)
    end
  end
end
