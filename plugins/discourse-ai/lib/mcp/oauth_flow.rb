# frozen_string_literal: true

require "base64"
require "openssl"

module DiscourseAi
  module Mcp
    class OAuthFlow
      STATE_TTL = 10.minutes

      OAuthError =
        Class.new(StandardError) do
          attr_reader :server

          def initialize(message = nil, server: nil)
            @server = server
            super(message)
          end
        end

      class << self
        def start!(server:, user:)
          validate_local_oauth_urls!(server)

          discovery = OAuthDiscovery.discover!(server)
          server.store_oauth_discovery!(discovery)

          if server.oauth_client_registration != "manual" && server.oauth_client_id.blank? &&
               discovery.registration_endpoint.present?
            OAuthClientRegistration.register!(server: server, discovery: discovery)
            server.reload
          end

          state = SecureRandom.hex(32)
          code_verifier = generate_code_verifier
          Rails.cache.write(
            state_cache_key(state),
            {
              "ai_mcp_server_id" => server.id,
              "user_id" => user.id,
              "code_verifier" => code_verifier,
            },
            expires_in: STATE_TTL,
          )

          build_authorization_url(
            server: server,
            discovery: discovery,
            state: state,
            code_verifier: code_verifier,
          )
        end

        def complete!(params:, current_user:)
          state = params[:state].to_s
          payload = Rails.cache.read(state_cache_key(state))
          Rails.cache.delete(state_cache_key(state))

          if payload.blank? || payload["user_id"].to_i != current_user.id
            raise DiscourseAi::Mcp::Client::Error,
                  I18n.t("discourse_ai.mcp_servers.errors.oauth_state_invalid")
          end

          server = AiMcpServer.find(payload["ai_mcp_server_id"])
          if params[:error].present?
            raise DiscourseAi::Mcp::Client::Error,
                  params[:error_description].presence || params[:error].to_s.tr("_", " ")
          end

          discovery = server.oauth_discovery_result || OAuthDiscovery.discover!(server)
          token_payload =
            token_request(
              server: server,
              endpoint: discovery.token_endpoint,
              params: {
                grant_type: "authorization_code",
                code: params[:code].to_s,
                redirect_uri: server.oauth_callback_url,
                code_verifier: payload["code_verifier"],
                client_id: server.effective_oauth_client_id,
                resource: discovery.resource.presence || server.url,
              },
            )

          store_token_response!(server, token_payload, preserve_refresh_token: false)
          server.mark_oauth_authorized!
          DiscourseAi::Mcp::ToolRegistry.invalidate!(server.id)
          AiAgent.agent_cache.flush!
          server
        rescue StandardError => e
          server&.mark_oauth_error!(e.message)
          raise OAuthError.new(e.message, server: server), cause: e
        end

        def refresh!(server)
          discovery = server.oauth_discovery_result || OAuthDiscovery.discover!(server)
          refresh_token = server.oauth_token_store.refresh_token
          if refresh_token.blank?
            raise DiscourseAi::Mcp::Client::Error,
                  I18n.t("discourse_ai.mcp_servers.errors.oauth_refresh_token_missing")
          end

          token_payload =
            token_request(
              server: server,
              endpoint: discovery.token_endpoint,
              params: {
                grant_type: "refresh_token",
                refresh_token: refresh_token,
                client_id: server.effective_oauth_client_id,
                resource: discovery.resource.presence || server.url,
              },
            )

          store_token_response!(server, token_payload, preserve_refresh_token: true)
          token_payload["access_token"]
        rescue StandardError => e
          server.mark_oauth_refresh_failed!(e.message)
          raise
        end

        def disconnect!(server)
          discovery = server.oauth_discovery_result

          if discovery&.revocation_endpoint.present?
            revoke_token(
              server,
              discovery.revocation_endpoint,
              server.oauth_token_store.access_token,
            )
            revoke_token(
              server,
              discovery.revocation_endpoint,
              server.oauth_token_store.refresh_token,
            )
          end

          server.clear_oauth_credentials!
          DiscourseAi::Mcp::ToolRegistry.invalidate!(server.id)
          AiAgent.agent_cache.flush!
        end

        private

        def build_authorization_url(server:, discovery:, state:, code_verifier:)
          code_challenge =
            Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier)).tr("+/", "-_").delete("=")

          query = {
            response_type: "code",
            client_id: server.effective_oauth_client_id,
            redirect_uri: server.oauth_callback_url,
            state: state,
            code_challenge: code_challenge,
            code_challenge_method: "S256",
            resource: discovery.resource.presence || server.url,
          }
          query[:scope] = server.oauth_scopes if server.oauth_scopes.present?

          uri = URI(discovery.authorization_endpoint)
          uri.query = Rack::Utils.build_query(query)
          uri.to_s
        end

        def token_request(server:, endpoint:, params:)
          connection =
            Faraday.new(request: { timeout: server.timeout_seconds }) do |builder|
              builder.request :url_encoded
              builder.adapter FinalDestination::FaradayAdapter
            end

          validate_endpoint!(endpoint)

          headers = { "Accept" => "application/json" }
          if server.oauth_client_secret_value.present?
            headers["Authorization"] = basic_auth_header(
              server.effective_oauth_client_id,
              server.oauth_client_secret_value,
            )
          end

          response = connection.post(endpoint, params, headers)

          if response.status != 200
            message =
              begin
                JSON.parse(response.body).dig("error_description")
              rescue StandardError
                nil
              end
            raise DiscourseAi::Mcp::Client::Error,
                  message.presence ||
                    I18n.t(
                      "discourse_ai.mcp_servers.errors.oauth_token_exchange_failed",
                      status: response.status,
                    )
          end

          JSON.parse(response.body)
        rescue JSON::ParserError
          raise DiscourseAi::Mcp::Client::Error,
                I18n.t("discourse_ai.mcp_servers.errors.invalid_response")
        end

        def store_token_response!(server, token_payload, preserve_refresh_token:)
          refresh_token =
            if preserve_refresh_token
              token_payload["refresh_token"].presence || server.oauth_token_store.refresh_token
            else
              token_payload["refresh_token"]
            end

          server.update_oauth_tokens!(
            access_token: token_payload["access_token"],
            refresh_token: refresh_token,
            token_type: token_payload["token_type"],
            expires_in: token_payload["expires_in"],
            granted_scopes: token_payload["scope"],
          )
        end

        def revoke_token(server, endpoint, token)
          return if token.blank?

          validate_endpoint!(endpoint)

          connection =
            Faraday.new(request: { timeout: server.timeout_seconds }) do |builder|
              builder.request :url_encoded
              builder.adapter FinalDestination::FaradayAdapter
            end

          headers = { "Accept" => "application/json" }
          if server.oauth_client_secret_value.present?
            headers["Authorization"] = basic_auth_header(
              server.effective_oauth_client_id,
              server.oauth_client_secret_value,
            )
          end

          connection.post(
            endpoint,
            { token: token, client_id: server.effective_oauth_client_id },
            headers,
          )
        rescue StandardError => e
          Rails.logger.warn(
            "Discourse AI MCP OAuth revoke failed for server #{server.id}: #{e.message}",
          )
        end

        def basic_auth_header(client_id, client_secret)
          "Basic #{Base64.strict_encode64("#{client_id}:#{client_secret}")}"
        end

        def generate_code_verifier
          Base64.urlsafe_encode64(OpenSSL::Random.random_bytes(32)).delete("=")
        end

        def state_cache_key(state)
          "discourse-ai:mcp-oauth-state:#{state}"
        end

        def validate_endpoint!(url)
          uri = AiMcpServer.parse_public_uri(url)
          if uri.nil?
            raise DiscourseAi::Mcp::Client::Error,
                  I18n.t("discourse_ai.mcp_servers.invalid_url_not_https")
          end

          AiMcpServer.validate_hostname_public!(uri.hostname)
        rescue FinalDestination::SSRFError, SocketError, URI::InvalidURIError
          raise DiscourseAi::Mcp::Client::Error,
                I18n.t("discourse_ai.mcp_servers.invalid_url_not_reachable")
        end

        def validate_local_oauth_urls!(server)
          callback_uri = URI.parse(server.oauth_callback_url)
          if callback_uri.scheme != "https"
            raise DiscourseAi::Mcp::Client::Error,
                  I18n.t("discourse_ai.mcp_servers.errors.oauth_https_required")
          end

          return if server.oauth_client_registration == "manual"

          metadata_url = server.oauth_client_metadata_url
          metadata_uri = AiMcpServer.parse_public_uri(metadata_url)
          if metadata_uri.nil?
            raise DiscourseAi::Mcp::Client::Error,
                  I18n.t(
                    "discourse_ai.mcp_servers.errors.oauth_client_metadata_public_https_required",
                    url: metadata_url,
                  )
          end

          AiMcpServer.validate_hostname_public!(metadata_uri.hostname)
        rescue FinalDestination::SSRFError, SocketError, URI::InvalidURIError
          raise DiscourseAi::Mcp::Client::Error,
                I18n.t(
                  "discourse_ai.mcp_servers.errors.oauth_client_metadata_public_https_required",
                  url: server.oauth_client_metadata_url,
                )
        end
      end
    end
  end
end
