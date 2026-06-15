# frozen_string_literal: true

require "faraday"

module Discourse
  class GithubApi
    API_ROOT = "https://api.github.com"
    ALLOWED_HOSTS = %w[api.github.com raw.githubusercontent.com].freeze
    DEFAULT_ACCEPT = "application/vnd.github+json"
    TIMEOUT = 5
    ETAG_MAX_BYTES = 512.kilobytes

    class Error < StandardError
      attr_reader :status

      def initialize(message = nil, status: nil)
        @status = status
        super(message || "GitHub API error (status #{status})")
      end
    end

    class NotFound < Error
    end

    class Unauthorized < Error
    end

    class RateLimited < Error
    end

    def self.for(token:)
      (@clients ||= {})[token.to_s] ||= new(token)
    end

    def self.reset_clients!
      @clients = {}
    end

    def initialize(token)
      @token = token.presence
    end

    def backing_off?
      GithubRateLimit.backing_off?(@token)
    end

    def get(path, accept: DEFAULT_ACCEPT, **params)
      body = request(:get, path, params:, accept:)
      body.present? ? ::MultiJson.load(body) : nil
    end

    def post(path, body = nil, accept: DEFAULT_ACCEPT)
      response_body = request(:post, path, body:, accept:)
      response_body.present? ? ::MultiJson.load(response_body) : nil
    end

    def raw_get(path, accept: DEFAULT_ACCEPT)
      request(:get, path, accept:, cache_etag: false)
    end

    private

    def request(method, path, params: {}, body: nil, accept:, cache_etag: true)
      raise RateLimited, "GitHub rate limit backoff active" if backing_off?

      url = path.start_with?("http") ? path : "#{API_ROOT}#{path}"
      host = URI.parse(url).host
      if ALLOWED_HOSTS.exclude?(host)
        raise ArgumentError, "Refusing to call non-GitHub host: #{host.inspect}"
      end

      etag_key = (etag_cache_key(url, params, accept) if cache_etag && method == :get)
      cached = (Discourse.cache.read(etag_key) if etag_key)

      response = perform(method, url, params:, body:, accept:, etag: cached&.dig(:etag))
      backed_off = GithubRateLimit.note_response_headers(response.headers, token: @token)

      case response.status
      when 200..299
        store_etag(etag_key, response) if etag_key
        response.body
      when 304
        cached&.dig(:body)
      when 401
        raise Unauthorized.new(status: 401)
      when 404
        raise NotFound.new(status: 404)
      else
        raise RateLimited.new("GitHub rate limited", status: response.status) if backed_off
        raise Error.new(status: response.status)
      end
    end

    def perform(method, url, params:, body:, accept:, etag:)
      headers = { "Accept" => accept, "User-Agent" => Discourse.user_agent }
      headers["Authorization"] = "Bearer #{@token}" if @token
      headers["If-None-Match"] = etag if etag.present?
      headers["Content-Type"] = "application/json" if body

      connection.run_request(method, url, body && ::MultiJson.dump(body), headers) do |req|
        req.params.update(params) if params.present?
        req.options.timeout = TIMEOUT
        req.options.open_timeout = TIMEOUT
      end
    rescue Faraday::Error => e
      raise Error.new("GitHub API request failed: #{e.message}")
    end

    def connection
      @connection ||= Faraday.new(nil) { |f| f.adapter FinalDestination::FaradayAdapter }
    end

    def etag_cache_key(url, params, accept)
      identity = @token ? Digest::SHA1.hexdigest(@token) : "anon"
      query = params.present? ? "?#{params.to_query}" : ""
      "github_etag:#{identity}:#{accept}:#{url}#{query}"
    end

    def store_etag(key, response)
      etag = response.headers["etag"]
      return if etag.blank? || response.body.to_s.bytesize > ETAG_MAX_BYTES

      Discourse.cache.write(key, { etag:, body: response.body }, expires_in: 1.day)
    end
  end
end
