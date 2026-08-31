# frozen_string_literal: true

module DiscourseZendeskPlugin
  class OAuthToken
    INVALIDATE_SCRIPT = DiscourseRedis::EvalHelper.new <<~LUA
        if redis.call("get", KEYS[1]) == ARGV[1] then
          return redis.call("del", KEYS[1])
        end

        return 0
      LUA
    private_constant :INVALIDATE_SCRIPT

    TOKEN_LIFETIME_SECONDS = 30.minutes.to_i
    private_constant :TOKEN_LIFETIME_SECONDS

    EXPIRY_BUFFER_SECONDS = 1.minute.to_i
    private_constant :EXPIRY_BUFFER_SECONDS

    OPEN_TIMEOUT_SECONDS = 5
    private_constant :OPEN_TIMEOUT_SECONDS

    READ_TIMEOUT_SECONDS = 10
    private_constant :READ_TIMEOUT_SECONDS

    WRITE_TIMEOUT_SECONDS = 5
    private_constant :WRITE_TIMEOUT_SECONDS

    SCOPES = "tickets:read tickets:write users:read users:write"
    private_constant :SCOPES

    class RequestError < StandardError
    end

    class PermanentRequestError < RequestError
    end

    def initialize
      @zendesk_url = SiteSetting.zendesk_url
      @client_id = SiteSetting.zendesk_oauth_client_id
      @client_secret = SiteSetting.zendesk_oauth_client_secret
    end

    def access_token
      Discourse.cache.read(cache_key).presence || request_access_token
    end

    def invalidate(access_token)
      INVALIDATE_SCRIPT.eval(
        Discourse.cache.redis,
        [Discourse.cache.redis.namespace_key(Discourse.cache.normalize_key(cache_key))],
        [Marshal.dump(access_token)],
      )
    end

    private

    def request_access_token
      response = http.request(token_request)
      unless response.is_a?(Net::HTTPSuccess)
        error_class = permanent_failure?(response) ? PermanentRequestError : RequestError
        raise error_class, "Zendesk OAuth token request failed"
      end

      payload = JSON.parse(response.body)
      access_token = payload["access_token"].presence
      expires_in_seconds = Integer(payload["expires_in"], exception: false)

      if access_token.blank? || expires_in_seconds.blank? || expires_in_seconds <= 0
        raise RequestError, "Zendesk OAuth token response is invalid"
      end

      Discourse.cache.write(
        cache_key,
        access_token,
        expires_in: [expires_in_seconds - EXPIRY_BUFFER_SECONDS, 1].max,
      )
      access_token
    rescue JSON::ParserError
      raise RequestError, "Zendesk OAuth token response is invalid"
    end

    def token_request
      FinalDestination::HTTP::Post
        .new(token_uri.request_uri)
        .tap do |request|
          request.set_form_data(
            grant_type: "client_credentials",
            client_id: @client_id,
            client_secret: @client_secret,
            scope: SCOPES,
            expires_in: TOKEN_LIFETIME_SECONDS,
          )
        end
    end

    def http
      FinalDestination::HTTP
        .new(token_uri.host, token_uri.port)
        .tap do |http|
          http.use_ssl = true
          http.open_timeout = OPEN_TIMEOUT_SECONDS
          http.read_timeout = READ_TIMEOUT_SECONDS
          http.write_timeout = WRITE_TIMEOUT_SECONDS
        end
    end

    def token_uri
      zendesk_uri = URI.parse(@zendesk_url)
      unless zendesk_uri.is_a?(URI::HTTPS) && zendesk_uri.host.present?
        raise PermanentRequestError, "Zendesk OAuth requires an HTTPS URL"
      end

      URI::HTTPS.build(host: zendesk_uri.host, port: zendesk_uri.port, path: "/oauth/tokens")
    rescue URI::InvalidURIError
      raise PermanentRequestError, "Zendesk OAuth requires an HTTPS URL"
    end

    def cache_key
      fingerprint = Digest::SHA256.hexdigest([@zendesk_url, @client_id, @client_secret].join("\0"))
      "discourse-zendesk-oauth-token:#{fingerprint}"
    end

    def permanent_failure?(response)
      status = response.code.to_i
      status.between?(400, 499) && ![408, 429].include?(status)
    end
  end
end
