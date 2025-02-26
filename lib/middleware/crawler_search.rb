# frozen_string_literal: true

require "crawler_detection"
require "http_user_agent_encoder"

module Middleware
  class CrawlerSearch
    def initialize(app)
      @app = app
    end

    def call(env)
      @env = env

      # Crawlers don't need to see search results.
      if should_hide_search_results?
        Middleware::AnonymousCache.disable_anon_cache

        return [
          200,
          { "Content-Type" => "text/html", "X-Robots-Tag" => "noindex" },
          [
            "<html><head><meta name='robots' content='noindex'></head><body><p>*waves hand* This is not the content you are looking for</p></body></html>",
          ]
        ]
      end

      @app.call(env)
    end

    def user_agent
      @user_agent ||= HttpUserAgentEncoder.ensure_utf8(@env["HTTP_USER_AGENT"])
    end

    def request
      @request ||= Rack::Request.new(@env)
    end

    def should_hide_search_results?
      get? && search_path? && search_query? && crawler_detected?
    end

    def get?
      request.get?
    end

    def search_path?
      request.path.starts_with?(Discourse.base_path + "/search")
    end

    def search_query?
      request.params["q"].present?
    end

    def crawler_detected?
      CrawlerDetection.crawler?(user_agent, @env["HTTP_VIA"])
    end
  end
end
