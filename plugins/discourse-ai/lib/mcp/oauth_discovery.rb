# frozen_string_literal: true

module DiscourseAi
  module Mcp
    class OAuthDiscovery
      Result =
        Struct.new(
          :resource,
          :resource_metadata_url,
          :issuer,
          :authorization_endpoint,
          :token_endpoint,
          :revocation_endpoint,
          :registration_endpoint,
          keyword_init: true,
        )

      class << self
        def discover!(server, challenge_header: nil)
          resource_metadata_url =
            challenge_parameters(challenge_header)["resource_metadata"] ||
              default_well_known_url(server.url, "oauth-protected-resource")

          resource_metadata = get_json!(server, resource_metadata_url)
          issuer =
            Array(resource_metadata["authorization_servers"]).first ||
              resource_metadata["authorization_server"]
          if issuer.blank?
            raise DiscourseAi::Mcp::Client::Error,
                  I18n.t("discourse_ai.mcp_servers.errors.oauth_discovery_failed")
          end

          auth_server_metadata =
            get_json!(server, default_well_known_url(issuer, "oauth-authorization-server"))
          authorization_endpoint = auth_server_metadata["authorization_endpoint"].presence
          token_endpoint = auth_server_metadata["token_endpoint"].presence

          if authorization_endpoint.blank? || token_endpoint.blank?
            raise DiscourseAi::Mcp::Client::Error,
                  I18n.t("discourse_ai.mcp_servers.errors.oauth_discovery_failed")
          end

          validate_discovered_url!(authorization_endpoint)
          validate_discovered_url!(token_endpoint)

          revocation_endpoint = auth_server_metadata["revocation_endpoint"].presence
          validate_discovered_url!(revocation_endpoint) if revocation_endpoint.present?

          registration_endpoint = auth_server_metadata["registration_endpoint"].presence
          validate_discovered_url!(registration_endpoint) if registration_endpoint.present?

          Result.new(
            resource: resource_metadata["resource"].presence || server.url,
            resource_metadata_url: resource_metadata_url,
            issuer: auth_server_metadata["issuer"].presence || issuer,
            authorization_endpoint: authorization_endpoint,
            token_endpoint: token_endpoint,
            revocation_endpoint: revocation_endpoint,
            registration_endpoint: registration_endpoint,
          )
        end

        def challenge_parameters(header)
          value = header.to_s[/Bearer\s+(.+)\z/i, 1]
          return {} if value.blank?

          value
            .scan(/([a-zA-Z_]+)="([^"]*)"|([a-zA-Z_]+)=([^,\s]+)/)
            .each_with_object({}) do |parts, hash|
              key = parts[0] || parts[2]
              parsed_value = parts[1] || parts[3]
              hash[key] = parsed_value if key.present?
            end
        end

        def default_well_known_url(raw_url, suffix)
          uri = AiMcpServer.parse_public_uri(raw_url)
          if uri.nil?
            raise DiscourseAi::Mcp::Client::Error,
                  I18n.t("discourse_ai.mcp_servers.invalid_url_not_https")
          end

          path = uri.path.to_s
          path = "" if path == "/"
          path = path.sub(%r{/\z}, "")

          duplicated = uri.dup
          duplicated.path = "/.well-known/#{suffix}#{path}"
          duplicated.query = nil
          duplicated.to_s
        end

        private

        def get_json!(server, url)
          uri = AiMcpServer.parse_public_uri(url)
          if uri.nil?
            raise DiscourseAi::Mcp::Client::Error,
                  I18n.t("discourse_ai.mcp_servers.invalid_url_not_https")
          end

          AiMcpServer.validate_hostname_public!(uri.hostname)

          response = nil
          FinalDestination::HTTP.start(
            uri.hostname,
            uri.port,
            use_ssl: true,
            open_timeout: server.timeout_seconds,
            read_timeout: server.timeout_seconds,
          ) do |http|
            request = FinalDestination::HTTP::Get.new(uri.request_uri)
            request["Accept"] = "application/json"
            request["User-Agent"] = DiscourseAi::Mcp::Client::USER_AGENT
            response = http.request(request)
          end

          if response.code.to_i != 200
            raise DiscourseAi::Mcp::Client::Error,
                  I18n.t(
                    "discourse_ai.mcp_servers.errors.oauth_discovery_failed_with_status",
                    status: response.code.to_i,
                  )
          end

          JSON.parse(response.body.presence || "{}")
        rescue JSON::ParserError
          raise DiscourseAi::Mcp::Client::Error,
                I18n.t("discourse_ai.mcp_servers.errors.oauth_discovery_failed")
        end

        def validate_discovered_url!(url)
          uri = AiMcpServer.parse_public_uri(url)
          if uri.nil?
            raise DiscourseAi::Mcp::Client::Error,
                  I18n.t("discourse_ai.mcp_servers.errors.oauth_discovery_failed")
          end

          AiMcpServer.validate_hostname_public!(uri.hostname)
        rescue FinalDestination::SSRFError, SocketError, URI::InvalidURIError
          raise DiscourseAi::Mcp::Client::Error,
                I18n.t("discourse_ai.mcp_servers.errors.oauth_discovery_failed")
        end
      end
    end
  end
end
