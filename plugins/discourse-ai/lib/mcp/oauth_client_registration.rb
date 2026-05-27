# frozen_string_literal: true

module DiscourseAi
  module Mcp
    class OAuthClientRegistration
      class << self
        def register!(server:, discovery:)
          endpoint = discovery.registration_endpoint
          if endpoint.blank?
            raise DiscourseAi::Mcp::Client::Error,
                  I18n.t("discourse_ai.mcp_servers.errors.oauth_registration_endpoint_missing")
          end

          validate_endpoint!(endpoint)

          metadata = build_client_metadata(server)

          connection =
            Faraday.new(request: { timeout: server.timeout_seconds }) do |builder|
              builder.request :json
              builder.adapter FinalDestination::FaradayAdapter
            end

          response = connection.post(endpoint, metadata, { "Accept" => "application/json" })

          if response.status != 201 && response.status != 200
            message =
              begin
                parsed = JSON.parse(response.body)
                parsed["error_description"] || parsed["error"]
              rescue StandardError
                nil
              end
            raise DiscourseAi::Mcp::Client::Error,
                  message.presence ||
                    I18n.t(
                      "discourse_ai.mcp_servers.errors.oauth_client_registration_failed",
                      status: response.status,
                    )
          end

          registration = JSON.parse(response.body)
          client_id = registration["client_id"]
          if client_id.blank?
            raise DiscourseAi::Mcp::Client::Error,
                  I18n.t("discourse_ai.mcp_servers.errors.oauth_client_registration_failed_no_id")
          end

          server.store_dynamic_registration!(
            client_id: client_id,
            client_secret: registration["client_secret"],
          )

          registration
        rescue JSON::ParserError
          raise DiscourseAi::Mcp::Client::Error,
                I18n.t("discourse_ai.mcp_servers.errors.invalid_response")
        end

        private

        def build_client_metadata(server)
          {
            client_name: SiteSetting.title.presence || "Discourse AI MCP Client",
            redirect_uris: [server.oauth_callback_url],
            grant_types: %w[authorization_code refresh_token],
            response_types: ["code"],
            application_type: "web",
            token_endpoint_auth_method: "none",
            scope: server.oauth_scopes.presence,
          }.compact
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
      end
    end
  end
end
