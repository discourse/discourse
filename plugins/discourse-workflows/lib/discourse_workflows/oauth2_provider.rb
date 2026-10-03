# frozen_string_literal: true

module DiscourseWorkflows
  class Oauth2Provider
    TIMEOUT_SECONDS = 10
    MAX_RESPONSE_BYTES = 64.kilobytes
    MAX_TOKEN_LIFETIME = 24.hours.to_i
    class Error < StandardError
      attr_reader :code

      def initialize(code = "provider_error")
        @code = code
        super(I18n.t("discourse_workflows.oauth2.errors.#{code}"))
      end
    end

    class Revoked < Error
      def initialize
        super("reconnect_required")
      end
    end

    def self.valid_https_url?(value, origin: false)
      return false unless value.is_a?(String) && value.length <= 4096
      uri = URI.parse(value)
      uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? && uri.fragment.nil? &&
        (!origin || (uri.path.in?(["", "/"]) && uri.query.nil?))
    rescue URI::InvalidURIError
      false
    end

    def initialize(credential)
      @credential = credential
    end

    def validate_configuration(credential)
      scope = credential.data["scope"]
      valid_scope =
        scope.nil? || (scope.is_a?(String) && scope.length <= 4096 && !scope.start_with?("="))
      configured_origin = credential.data["api_origin"]
      valid_origin = self.class.valid_https_url?(configured_origin, origin: true)
      resolved_revoke_url = revoke_url
      valid_revoke_url =
        resolved_revoke_url.blank? || self.class.valid_https_url?(resolved_revoke_url)
      lifetime = credential.data["token_lifetime"]
      parsed_lifetime = Integer(lifetime, exception: false)
      valid_lifetime =
        lifetime.blank? || (parsed_lifetime&.positive? && parsed_lifetime <= MAX_TOKEN_LIFETIME)
      unless self.class.valid_https_url?(token_url) && valid_origin && valid_revoke_url &&
               valid_lifetime &&
               credential
                 .data
                 .fetch("token_auth_method", "request_body")
                 .in?(%w[request_body http_basic]) && valid_scope
        credential.errors.add(
          :data,
          I18n.t("discourse_workflows.oauth2.errors.invalid_configuration"),
        )
      end
    end

    def authenticate
      raise Error.new("invalid_configuration") unless self.class.valid_https_url?(token_url)
      result =
        parse_response(
          request(:post, token_url, form: token_parameters, headers: client_auth_headers),
        )
      validate_tokens!(result)
      result
    end

    def token_url
      # Let authenticate report a missing endpoint as a configuration error.
      @credential.data["token_url"]
    end

    def revoke_url
      @credential.data["revoke_url"].presence
    end

    def assumed_token_lifetime
      value = Integer(@credential.data["token_lifetime"], exception: false)
      value if value&.positive?
    end

    def token_parameters
      form = { grant_type: "client_credentials" }
      form[:scope] = @credential.data["scope"] if @credential.data["scope"].present?
      form.merge(client_auth_parameters)
    end

    def validate_tokens!(tokens)
      unless tokens["access_token"].is_a?(String) && tokens["access_token"].present? &&
               !tokens["access_token"].match?(/[\r\n]/) &&
               tokens["token_type"].to_s.casecmp?("Bearer")
        raise Error.new("invalid_response")
      end
    end

    def connection_details
      origin = @credential.data["api_origin"].presence
      return [] unless origin
      [{ label: I18n.t("discourse_workflows.oauth2.api_origin"), value: origin }]
    end

    def validate_api_url!(url)
      validate_api_origin!(url, @credential.data.fetch("api_origin"))
    end

    def revoke(token)
      url = revoke_url
      return if url.blank?
      response =
        request(
          :post,
          url,
          form: { token: token }.merge(client_auth_parameters),
          headers: client_auth_headers,
        )
      return if response.status == 200
      if response.status == 400
        body = parse_revocation_response(response.body)
        return if body["error"].in?(%w[invalid_token invalid_grant])
      end
      raise Error.new("revocation_failed")
    end

    protected

    def client_auth_parameters
      return {} if @credential.data["token_auth_method"] == "http_basic"
      {
        client_id: @credential.data.fetch("client_id"),
        client_secret: @credential.oauth_client_secret,
      }
    end

    def client_auth_headers
      return {} unless @credential.data["token_auth_method"] == "http_basic"
      credentials =
        [@credential.data.fetch("client_id"), @credential.oauth_client_secret].map do |value|
            URI.encode_www_form_component(value)
          end
          .join(":")
      { "Authorization" => "Basic #{Base64.strict_encode64(credentials)}" }
    end

    def validate_api_origin!(url, origin)
      unless self.class.valid_https_url?(url) && self.class.valid_https_url?(origin, origin: true)
        raise Error.new("invalid_api_host")
      end
      uri = URI.parse(url)
      instance = URI.parse(origin)
      unless uri.host == instance.host && uri.port == instance.port
        raise Error.new("invalid_api_host")
      end
    end

    def parse_response(response)
      body = parse_json(response.body)
      raise Revoked if response.status == 400 && body["error"] == "invalid_grant"
      raise Error if response.status != 200
      body
    end

    def parse_json(body)
      raise Error.new("invalid_response") if body.to_s.bytesize > MAX_RESPONSE_BYTES
      result = JSON.parse(body)
      raise Error.new("invalid_response") unless result.is_a?(Hash)
      result
    rescue JSON::ParserError, TypeError
      raise Error.new("invalid_response")
    end

    def parse_revocation_response(body)
      return parse_json(body) unless body.to_s.start_with?("error=")
      raise Error.new("invalid_response") if body.bytesize > MAX_RESPONSE_BYTES
      URI.decode_www_form(body).to_h
    rescue ArgumentError
      raise Error.new("invalid_response")
    end

    def request(method, url, form: nil, headers: {})
      headers = { "Accept" => "application/json" }.merge(headers)
      headers["Content-Type"] = "application/x-www-form-urlencoded" if form
      connection.run_request(method, url, form && URI.encode_www_form(form), headers)
    rescue Faraday::Error, FinalDestination::SSRFDetector::DisallowedIpError, SocketError
      raise Error.new("provider_unavailable")
    end

    def connection
      @connection ||=
        Faraday.new(
          nil,
          request: {
            timeout: TIMEOUT_SECONDS,
            open_timeout: TIMEOUT_SECONDS,
            write_timeout: TIMEOUT_SECONDS,
          },
        ) { |faraday| faraday.adapter FinalDestination::FaradayAdapter }
    end
  end
end
