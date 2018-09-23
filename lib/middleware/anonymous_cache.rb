# frozen_string_literal: true

require_dependency "mobile_detection"
require_dependency "crawler_detection"
require_dependency "guardian"

module Middleware
  class AnonymousCache

    def self.anon_cache(env, duration)
      env["ANON_CACHE_DURATION"] = duration
    end

    class Helper
      USER_AGENT = "HTTP_USER_AGENT"
      RACK_SESSION = "rack.session"
      ACCEPT_ENCODING = "HTTP_ACCEPT_ENCODING"

      def initialize(env)
        @env = env
        @request = Rack::Request.new(@env)
      end

      def blocked_crawler?
        @request.get? &&
        !@request.xhr? &&
        !@request.path.ends_with?('robots.txt') &&
        !@request.path.ends_with?('srv/status') &&
        @request[Auth::DefaultCurrentUserProvider::API_KEY].nil? &&
        @env[Auth::DefaultCurrentUserProvider::USER_API_KEY].nil? &&
        CrawlerDetection.is_blocked_crawler?(@request.env['HTTP_USER_AGENT'])
      end

      def is_mobile=(val)
        @is_mobile = val ? :true : :false
      end

      def is_mobile?
        @is_mobile ||=
          begin
            session = @env[RACK_SESSION]
            # don't initialize params until later otherwise
            # you get a broken params on the request
            params = {}
            user_agent = @env[USER_AGENT]

            MobileDetection.resolve_mobile_view!(user_agent, params, session) ? :true : :false
          end

        @is_mobile == :true
      end

      def has_brotli?
        @has_brotli ||=
          begin
            @env[ACCEPT_ENCODING].to_s =~ /br/ ? :true : :false
          end
        @has_brotli == :true
      end

      def is_crawler?
        @is_crawler ||=
          begin
            user_agent = @env[USER_AGENT]
            CrawlerDetection.crawler?(user_agent) ? :true : :false
          end
        @is_crawler == :true
      end

      def cache_key
        @cache_key ||= "ANON_CACHE_#{@env["HTTP_ACCEPT"]}_#{@env["HTTP_HOST"]}#{@env["REQUEST_URI"]}|m=#{is_mobile?}|c=#{is_crawler?}|b=#{has_brotli?}|t=#{theme_ids.join(",")}"
      end

      def theme_ids
        ids, _ = @request.cookies['theme_ids']&.split('|')
        ids = ids&.split(",")&.map(&:to_i)
        if ids && Guardian.new.allow_themes?(ids)
          Theme.transform_ids(ids)
        else
          []
        end
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
        request.cookies['_bypass_cache'].nil? &&
          request[Auth::DefaultCurrentUserProvider::API_KEY].nil? &&
          @env[Auth::DefaultCurrentUserProvider::USER_API_KEY].nil?
      end

      def force_anonymous!
        @env[Auth::DefaultCurrentUserProvider::USER_API_KEY] = nil
        @env['HTTP_COOKIE'] = nil
        @env['rack.request.cookie.hash'] = {}
        @env['rack.request.cookie.string'] = ''
        @env['_bypass_cache'] = nil
        request = Rack::Request.new(@env)
        request.delete_param('api_username')
        request.delete_param('api_key')
      end

      def logged_in_anon_limiter
        @logged_in_anon_limiter ||= RateLimiter.new(
          nil,
          "logged_in_anon_cache_#{@env["HOST"]}/#{@env["REQUEST_URI"]}",
          GlobalSetting.force_anonymous_min_per_10_seconds,
          10
        )
      end

      def check_logged_in_rate_limit!
        !logged_in_anon_limiter.performed!(raise_error: false)
      end

      MIN_TIME_TO_CHECK = 0.05

      def should_force_anonymous?
        if (queue_time = @env['REQUEST_QUEUE_SECONDS']) && get?
          if queue_time > GlobalSetting.force_anonymous_min_queue_seconds
            return check_logged_in_rate_limit!
          elsif queue_time >= MIN_TIME_TO_CHECK
            if !logged_in_anon_limiter.can_perform?
              return check_logged_in_rate_limit!
            end
          end
        end

        false
      end

      def cacheable?
        !!(!has_auth_cookie? && get? && no_cache_bypass)
      end

      def cached
        if body = $redis.get(cache_key_body)
          if other = $redis.get(cache_key_other)
            other = JSON.parse(other)
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
      def cache(result)
        status, headers, response = result

        if status == 200 && cache_duration
          headers_stripped = headers.dup.delete_if { |k, _| ["Set-Cookie", "X-MiniProfiler-Ids"].include? k }
          headers_stripped["X-Discourse-Cached"] = "true"
          parts = []
          response.each do |part|
            parts << part
          end

          $redis.setex(cache_key_body,  cache_duration, parts.join)
          $redis.setex(cache_key_other, cache_duration, [status, headers_stripped].to_json)
        else
          parts = response
        end

        [status, headers, parts]
      end

      def clear_cache
        $redis.del(cache_key_body)
        $redis.del(cache_key_other)
      end

    end

    def initialize(app, settings = {})
      @app = app
    end

    def call(env)
      helper = Helper.new(env)
      force_anon = false

      if helper.blocked_crawler?
        env["discourse.request_tracker.skip"] = true
        return [403, {}, ["Crawler is not allowed!"]]
      end

      if helper.should_force_anonymous?
        force_anon = env["DISCOURSE_FORCE_ANON"] = true
        helper.force_anonymous!
      end

      result =
        if helper.cacheable?
          helper.cached || helper.cache(@app.call(env))
        else
          @app.call(env)
        end

      if force_anon
        result[1]["Set-Cookie"] = "dosp=1; Path=/"
      end

      result

    end

  end

end
