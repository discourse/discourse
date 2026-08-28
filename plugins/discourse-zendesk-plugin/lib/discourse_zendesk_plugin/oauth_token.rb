# frozen_string_literal: true

module DiscourseZendeskPlugin
  class OAuthToken
    TOKEN_LIFETIME_SECONDS = 30.minutes.to_i
    private_constant :TOKEN_LIFETIME_SECONDS

    EXPIRY_BUFFER_SECONDS = 1.minute.to_i
    private_constant :EXPIRY_BUFFER_SECONDS

    OPEN_TIMEOUT_SECONDS = 5
    private_constant :OPEN_TIMEOUT_SECONDS

    READ_TIMEOUT_SECONDS = 10
    private_constant :READ_TIMEOUT_SECONDS

    SCOPES = "tickets:read tickets:write users:read users:write"
    private_constant :SCOPES

    class RequestError < StandardError
    end

    def initialize
      @zendesk_url = SiteSetting.zendesk_url
      @client_id = SiteSetting.zendesk_oauth_client_id
      @client_secret = SiteSetting.zendesk_oauth_client_secret
    end

    def access_token
      Discourse.cache.read(cache_key).presence || request_access_token
    end

    def invalidate
      Discourse.cache.delete(cache_key)
    end

    private

    def request_access_token
      response = http.request(token_request)
      unless response.is_a?(Net::HTTPSuccess)
        raise RequestError, "Zendesk OAuth token request failed"
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
        end
    end

    def token_uri
      zendesk_uri = URI.parse(@zendesk_url)
      unless zendesk_uri.is_a?(URI::HTTPS) && zendesk_uri.host.present?
        raise RequestError, "Zendesk OAuth requires an HTTPS URL"
      end

      URI::HTTPS.build(host: zendesk_uri.host, port: zendesk_uri.port, path: "/oauth/tokens")
    rescue URI::InvalidURIError
      raise RequestError, "Zendesk OAuth requires an HTTPS URL"
    end

    def cache_key
      fingerprint = Digest::SHA256.hexdigest([@zendesk_url, @client_id, @client_secret].join("\0"))
      "discourse-zendesk-oauth-token:#{fingerprint}"
    end
  end
end
