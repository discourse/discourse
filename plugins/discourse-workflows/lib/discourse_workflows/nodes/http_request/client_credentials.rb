# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module HttpRequest
      class ClientCredentials
        extend NodeErrorHandling

        TOKEN_CACHE_PREFIX = "discourse_workflows:oauth2_client_credentials"
        DEFAULT_TOKEN_TTL_SECONDS = 10.minutes.to_i
        MAX_TOKEN_TTL_SECONDS = 1.hour.to_i
        TOKEN_EXPIRY_SKEW_SECONDS = 1.minute.to_i

        def self.fetch(credentials)
          cache_key = token_cache_key(credentials)
          cached_token = Discourse.cache.read(cache_key)
          return cached_token if cached_token.present?

          token, expires_in = request_token(credentials)
          Discourse.cache.write(cache_key, token, expires_in: token_ttl(expires_in))
          token
        end

        def self.request_token(credentials)
          headers = {
            "Accept" => "application/json",
            "Content-Type" => "application/x-www-form-urlencoded",
          }
          form = { "grant_type" => "client_credentials" }
          scope = credentials["scope"].to_s.strip
          form["scope"] = scope if scope.present?

          case credentials.fetch("client_authentication", "request_body")
          when "request_body"
            form["client_id"] = credentials["client_id"]
            form["client_secret"] = credentials["client_secret"]
          when "basic_auth"
            credentials_value = "#{credentials["client_id"]}:#{credentials["client_secret"]}"
            headers["Authorization"] = "Basic #{Base64.strict_encode64(credentials_value)}"
          else
            raise_node_error!(
              I18n.t(
                "discourse_workflows.errors.http_request.oauth2_unsupported_client_authentication",
              ),
            )
          end

          method, url, request_headers, body =
            RequestBuilder.new(
              {
                "method" => "POST",
                "url" => credentials["token_url"],
                "headers" => headers,
                "body" => URI.encode_www_form(form),
              },
            ).build
          response = connection.run_request(method, url.to_s, body, request_headers)

          unless (200..299).cover?(response.status)
            raise_node_error!(
              I18n.t(
                "discourse_workflows.errors.http_request.oauth2_token_request_failed",
                status: response.status,
              ),
            )
          end

          response_body = JSON.parse(response.body)
          access_token = response_body["access_token"] if response_body.is_a?(Hash)
          if access_token.blank?
            raise_node_error!(
              I18n.t("discourse_workflows.errors.http_request.oauth2_access_token_missing"),
            )
          end

          [access_token, response_body["expires_in"]]
        rescue JSON::ParserError
          raise_node_error!(
            I18n.t("discourse_workflows.errors.http_request.oauth2_token_response_invalid"),
          )
        end

        def self.token_cache_key(credentials)
          fingerprint =
            OpenSSL::HMAC.hexdigest(
              "SHA256",
              GlobalSetting.safe_secret_key_base,
              JSON.generate(credentials.stringify_keys),
            )
          "#{TOKEN_CACHE_PREFIX}:#{fingerprint}"
        end

        def self.token_ttl(expires_in)
          lifetime = Integer(expires_in, exception: false)
          return DEFAULT_TOKEN_TTL_SECONDS if lifetime.nil? || lifetime <= 0

          (lifetime - TOKEN_EXPIRY_SKEW_SECONDS).clamp(1, MAX_TOKEN_TTL_SECONDS)
        end

        def self.connection
          Faraday.new(
            nil,
            request: {
              timeout: Executor::HttpClient::TIMEOUT_SECONDS,
              open_timeout: Executor::HttpClient::TIMEOUT_SECONDS,
              write_timeout: Executor::HttpClient::TIMEOUT_SECONDS,
            },
          ) { |faraday| faraday.adapter FinalDestination::FaradayAdapter }
        end

        private_class_method :connection
      end
    end
  end
end
