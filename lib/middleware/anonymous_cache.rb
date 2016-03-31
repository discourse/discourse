require_dependency "mobile_detection"
require_dependency "crawler_detection"

module Middleware
  class AnonymousCache

    def self.anon_cache(env, duration)
      env["ANON_CACHE_DURATION"] = duration
    end

    class Helper
      USER_AGENT = "HTTP_USER_AGENT".freeze
      RACK_SESSION = "rack.session".freeze

      def initialize(env)
        @env = env
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
            user_agent  = @env[USER_AGENT]

            MobileDetection.resolve_mobile_view!(user_agent,params,session) ? :true : :false
          end

        @is_mobile == :true
      end

      def is_crawler?
        @is_crawler ||=
          begin
            user_agent  = @env[USER_AGENT]
            CrawlerDetection.crawler?(user_agent) ? :true : :false
          end
        @is_crawler == :true
      end

      def cache_key
        @cache_key ||= "ANON_CACHE_#{@env["HTTP_ACCEPT"]}_#{@env["HTTP_HOST"]}#{@env["REQUEST_URI"]}|m=#{is_mobile?}|c=#{is_crawler?}"
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
        request.cookies['_bypass_cache'].nil?
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
        status,headers,response = result

        if status == 200 && cache_duration
          headers_stripped = headers.dup.delete_if{|k, _| ["Set-Cookie","X-MiniProfiler-Ids"].include? k}
          headers_stripped["X-Discourse-Cached"] = "true"
          parts = []
          response.each do |part|
            parts << part
          end

          $redis.setex(cache_key_body,  cache_duration, parts.join)
          $redis.setex(cache_key_other, cache_duration, [status,headers_stripped].to_json)
        else
          parts = response
        end

        [status,headers,parts]
      end

      def clear_cache
        $redis.del(cache_key_body)
        $redis.del(cache_key_other)
      end

    end

    def initialize(app, settings={})
      @app = app
    end

    def call(env)
      helper = Helper.new(env)

      if helper.cacheable?
        helper.cached or helper.cache(@app.call(env))
      else
        @app.call(env)
      end

    end

  end

end
