module Middleware
  class AnonymousCache

    def self.anon_cache(env, duration)
      env["ANON_CACHE_DURATION"] = duration
    end

    class Helper
      def initialize(env)
        @env = env
      end

      def cache_key
        @cache_key ||= "ANON_CACHE_#{@env["HTTP_HOST"]}#{@env["REQUEST_URI"]}"
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

      def cacheable?
        !!(!CurrentUser.has_auth_cookie?(@env) && get?)
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
          headers_stripped = headers.dup.delete_if{|k,v| ["Set-Cookie","X-MiniProfiler-Ids"].include? k}
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
