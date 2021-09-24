# frozen_string_literal: true

module Middleware
  class EarlyHints
    def initialize(app)
      @app = app
    end

    def call(env)
      @request = ActionDispatch::Request.new(env)
      if hints_useful?
        @request.send_early_hints("Link" => links)
      end
      @app.call(env)
    end

    private

    # Not compreensive but still useful
    def hints_useful?
      @request.get? &&
      !@request.xhr? &&
      !@request.path.ends_with?('robots.txt') &&
      !@request.path.ends_with?('srv/status') &&
      @request[Auth::DefaultCurrentUserProvider::API_KEY].nil?
    end

    def links
      unless hints = Discourse.redis.get(hints_cache_key)
        hints = hints_list
        Discourse.redis.setex(hints_cache_key, hints_cache_duration, hints)
      end

      hints
    end

    def hints_cache_key
      "discourse-early-hints-cache"
    end

    def hints_cache_duration
      5 * 60
    end

    def hints_list
      js_hints = %w(
        application.js
        vendor.js
      )

      js_hints.map do |asset|
        hint_builder(
          UrlHelper.absolute("/assets/#{manifest_asset(asset)}"),
          'script'
        )
      end.join(',')
    end

    def hint_builder(url, type)
      "<#{url}>; rel=\"preload\"; as=\"#{type}\""
    end

    def manifest_asset(asset)
      Rails.application.assets_manifest.files.detect { |k, v| v['logical_path'] == asset }.first
    end
  end
end
