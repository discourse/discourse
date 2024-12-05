# frozen_string_literal: true

require "mobile_detection"
require "crawler_detection"
require "guardian"
require "http_language_parser"
require "http_user_agent_encoder"

module Middleware
  class AnonymousCache
    def self.cache_key_segments
      @@cache_key_segments ||= {
        m: "key_is_mobile?",
        c: "key_is_crawler?",
        o: "key_is_old_browser?",
        d: "key_is_modern_mobile_device?",
        b: "key_has_brotli?",
        t: "key_cache_theme_ids",
        ca: "key_compress_anon",
        l: "key_locale",
      }
    end

    # Compile a string builder method that will be called to create
    # an anonymous cache key
    def self.compile_key_builder
      method = +"def self.__compiled_key_builder(h)\n  \""
      cache_key_segments.each do |k, v|
        raise "Invalid key name" unless k =~ /\A[a-z]+\z/
        raise "Invalid method name" unless v =~ /\Akey_[a-z_\?]+\z/
        method << "|#{k}=#\{h.#{v}}"
      end
      method << "\"\nend"
      eval(method) # rubocop:disable Security/Eval
      @@compiled = true
    end

    def self.build_cache_key(helper)
      compile_key_builder unless defined?(@@compiled)
      __compiled_key_builder(helper)
    end

    def self.anon_cache(env, duration)
      env["ANON_CACHE_DURATION"] = duration
    end

    def self.clear_all_cache!
      if Rails.env.production?
        raise "for perf reasons, clear_all_cache! cannot be used in production."
      end
      Discourse.redis.keys("ANON_CACHE_*").each { |k| Discourse.redis.del(k) }
    end

    def self.disable_anon_cache
      @@disabled = true
    end

    def self.enable_anon_cache
      @@disabled = false
    end

    # This gives us an API to insert anonymous cache segments
    class Helper
      RACK_SESSION = "rack.session"
      USER_AGENT = "HTTP_USER_AGENT"
      ACCEPT_ENCODING = "HTTP_ACCEPT_ENCODING"
      DISCOURSE_RENDER = "HTTP_DISCOURSE_RENDER"

      REDIS_STORE_SCRIPT = DiscourseRedis::EvalHelper.new <<~LUA
        local current = redis.call("incr", KEYS[1])
        redis.call("expire",KEYS[1],ARGV[1])
        return current
      LUA

      def initialize(env, request = nil)
        @env = env
        @user_agent = HttpUserAgentEncoder.ensure_utf8(@env[USER_AGENT])
        @request = request || Rack::Request.new(@env)
      end

      def crawler_identifier
        @user_agent
      end

      def blocked_crawler?
        @request.get? && !@request.xhr? && !@request.path.ends_with?("robots.txt") &&
          !@request.path.ends_with?("srv/status") &&
          @request[Auth::DefaultCurrentUserProvider::API_KEY].nil? &&
          @env[Auth::DefaultCurrentUserProvider::USER_API_KEY].nil? &&
          @env[Auth::DefaultCurrentUserProvider::HEADER_API_KEY].nil? &&
          CrawlerDetection.is_blocked_crawler?(crawler_identifier)
      end

      # rubocop:disable Lint/BooleanSymbol
      def is_mobile=(val)
        @is_mobile = val ? :true : :false
      end

      def is_mobile?
        @is_mobile ||=
          begin
            session = @env[RACK_SESSION]
            # don't initialize params until later
            # otherwise you get a broken params on the request
            params = {}

            MobileDetection.resolve_mobile_view!(@user_agent, params, session) ? :true : :false
          end

        @is_mobile == :true
      end
      alias_method :key_is_mobile?, :is_mobile?

      def key_has_brotli?
        @has_brotli ||=
          begin
            @env[ACCEPT_ENCODING].to_s =~ /br/ ? :true : :false
          end
        @has_brotli == :true
      end
      # rubocop:enable Lint/BooleanSymbol

      def key_locale
        if locale = Discourse.anonymous_locale(@request)
          locale
        else
          "" # No need to key, it is the same for all anon users
        end
      end

      # rubocop:disable Lint/BooleanSymbol
      def is_crawler?
        @is_crawler ||=
          begin
            if @env[DISCOURSE_RENDER] == "crawler" ||
                 CrawlerDetection.crawler?(@user_agent, @env["HTTP_VIA"])
              :true
            else
              if @user_agent.downcase.include?("discourse") &&
                   !@user_agent.downcase.include?("mobile")
                :true
              else
                :false
              end
            end
          end
        @is_crawler == :true
      end
      alias_method :key_is_crawler?, :is_crawler?
      # rubocop:enable Lint/BooleanSymbol

      def key_is_modern_mobile_device?
        MobileDetection.modern_mobile_device?(@user_agent) if @user_agent
      end

      def key_is_old_browser?
        CrawlerDetection.show_browser_update?(@user_agent) if @user_agent
      end

      def cache_key
        return @cache_key if defined?(@cache_key)

        # Rack `xhr?` performs a case sensitive comparison, but Rails `xhr?`
        # performs a case insensitive comparison. We use the latter everywhere
        # else in the application, so we should use it here as well.
        is_xhr = @env["HTTP_X_REQUESTED_WITH"]&.casecmp("XMLHttpRequest") == 0 ? "t" : "f"

        @cache_key =
          +"ANON_CACHE_#{is_xhr}_#{@env["HTTP_ACCEPT"]}_#{@env[Rack::RACK_URL_SCHEME]}_#{@env["HTTP_HOST"]}#{@env["REQUEST_URI"]}"

        @cache_key << AnonymousCache.build_cache_key(self)
        @cache_key
      end

      def key_cache_theme_ids
        theme_ids.join(",")
      end

      def key_compress_anon
        GlobalSetting.compress_anon_cache
      end

      def theme_ids
        ids, _ = @request.cookies["theme_ids"]&.split("|")
        id = ids&.split(",")&.map(&:to_i)&.first
        if id && Guardian.new.allow_themes?([id])
          Theme.transform_ids(id)
        else
          []
        end
      end

      def cache_key_count
        @cache_key_count ||= "#{cache_key}_count"
      end

      def cache_key_body
        @cache_key_body ||= "#{cache_key}_body"
      end

      def cache_key_other
        @cache_key_other || "#{cache_key}_other"
      end

      def get?
        @env["REQUEST_METHOD"] == "GET"
      end

      def has_auth_cookie?
        CurrentUser.has_auth_cookie?(@env)
      end

      def no_cache_bypass
        request = Rack::Request.new(@env)
        request.cookies["_bypass_cache"].nil? && (request.path != "/srv/status") &&
          request[Auth::DefaultCurrentUserProvider::API_KEY].nil? &&
          @env[Auth::DefaultCurrentUserProvider::HEADER_API_KEY].nil? &&
          @env[Auth::DefaultCurrentUserProvider::USER_API_KEY].nil?
      end

      def force_anonymous!
        @env[Auth::DefaultCurrentUserProvider::USER_API_KEY] = nil
        @env[Auth::DefaultCurrentUserProvider::HEADER_API_KEY] = nil
        @env["HTTP_COOKIE"] = nil
        @env["HTTP_DISCOURSE_LOGGED_IN"] = nil
        @env["rack.request.cookie.hash"] = {}
        @env["rack.request.cookie.string"] = ""
        @env["_bypass_cache"] = nil
        request = Rack::Request.new(@env)
        request.delete_param("api_username")
        request.delete_param("api_key")
      end

      def logged_in_anon_limiter
        @logged_in_anon_limiter ||=
          RateLimiter.new(
            nil,
            "logged_in_anon_cache_#{@env["HTTP_HOST"]}/#{@env["REQUEST_URI"]}",
            GlobalSetting.force_anonymous_min_per_10_seconds,
            10,
          )
      end

      def check_logged_in_rate_limit!
        !logged_in_anon_limiter.performed!(raise_error: false)
      end

      MIN_TIME_TO_CHECK = 0.05
      ADP = "action_dispatch.request.parameters"

      def should_force_anonymous?
        if (queue_time = @env["REQUEST_QUEUE_SECONDS"]) && get?
          if queue_time > GlobalSetting.force_anonymous_min_queue_seconds
            return check_logged_in_rate_limit!
          elsif queue_time >= MIN_TIME_TO_CHECK
            return check_logged_in_rate_limit! if !logged_in_anon_limiter.can_perform?
          end
        end

        false
      end

      def cacheable?
        !!(
          GlobalSetting.anon_cache_store_threshold > 0 && !has_auth_cookie? && get? &&
            no_cache_bypass
        )
      end

      def compress(val)
        if val && GlobalSetting.compress_anon_cache
          require "lz4-ruby" if !defined?(LZ4)
          LZ4.compress(val)
        else
          val
        end
      end

      def decompress(val)
        if val && GlobalSetting.compress_anon_cache
          require "lz4-ruby" if !defined?(LZ4)
          LZ4.uncompress(val)
        else
          val
        end
      end

      def cached(env = {})
        if body = decompress(Discourse.redis.get(cache_key_body))
          if other = Discourse.redis.get(cache_key_other)
            other = JSON.parse(other)
            if req_params = other[1].delete(ADP)
              env[ADP] = req_params
            end
            [other[0], other[1], [body]]
          end
        end
      end

      def cache_duration
        @env["ANON_CACHE_DURATION"]
      end

      # NOTE in an ideal world cache still serves out cached content except for one magic worker
      #  that fills it up, this avoids a herd killing you, we can probably do this using a job or redis tricks
      #  but coordinating this is tricky
      def cache(result, env = {})
        return result if GlobalSetting.anon_cache_store_threshold == 0

        status, headers, response = result

        if status == 200 && cache_duration
          if GlobalSetting.anon_cache_store_threshold > 1
            count = REDIS_STORE_SCRIPT.eval(Discourse.redis, [cache_key_count], [cache_duration])

            # technically lua will cast for us, but might as well be
            # prudent here, hence the to_i
            if count.to_i < GlobalSetting.anon_cache_store_threshold
              headers["X-Discourse-Cached"] = "skip"
              return status, headers, response
            end
          end

          headers_stripped =
            headers.dup.delete_if { |k, _| %w[Set-Cookie X-MiniProfiler-Ids].include? k }
          headers_stripped["X-Discourse-Cached"] = "true"
          parts = []
          response.each { |part| parts << part }

          if req_params = env[ADP]
            headers_stripped[ADP] = {
              "action" => req_params["action"],
              "controller" => req_params["controller"],
            }
          end

          Discourse.redis.setex(cache_key_body, cache_duration, compress(parts.join))
          Discourse.redis.setex(cache_key_other, cache_duration, [status, headers_stripped].to_json)

          headers["X-Discourse-Cached"] = "store"
        else
          parts = response
        end

        [status, headers, parts]
      end

      def clear_cache
        Discourse.redis.del(cache_key_body)
        Discourse.redis.del(cache_key_other)
      end
    end

    def initialize(app, settings = {})
      @app = app
    end

    PAYLOAD_INVALID_REQUEST_METHODS = %w[GET HEAD]

    def call(env)
      return @app.call(env) if defined?(@@disabled) && @@disabled

      if PAYLOAD_INVALID_REQUEST_METHODS.include?(env[Rack::REQUEST_METHOD]) &&
           env[Rack::RACK_INPUT].size > 0
        return 413, { "Cache-Control" => "private, max-age=0, must-revalidate" }, []
      end

      helper = Helper.new(env)
      force_anon = false

      if helper.blocked_crawler?
        env["discourse.request_tracker.skip"] = true
        return 403, {}, ["Crawler is not allowed!"]
      end

      if helper.should_force_anonymous?
        force_anon = env["DISCOURSE_FORCE_ANON"] = true
        helper.force_anonymous!
      end

      if (env["HTTP_DISCOURSE_BACKGROUND"] == "true") && (queue_time = env["REQUEST_QUEUE_SECONDS"])
        max_time = GlobalSetting.background_requests_max_queue_length.to_f
        if max_time > 0 && queue_time.to_f > max_time
          return [
            429,
            { "content-type" => "application/json; charset=utf-8" },
            [
              {
                errors: I18n.t("rate_limiter.slow_down"),
                extras: {
                  wait_seconds: 5 + (5 * rand).round(2),
                },
              }.to_json,
            ]
          ]
        end
      end

      result =
        if helper.cacheable?
          helper.cached(env) || helper.cache(@app.call(env), env)
        else
          @app.call(env)
        end

      result[1]["Set-Cookie"] = "dosp=1; Path=/" if force_anon

      result
    end
  end
end
