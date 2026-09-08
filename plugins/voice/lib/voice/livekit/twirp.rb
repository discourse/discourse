# frozen_string_literal: true

module Voice
  module Livekit
    # Shared HTTP layer for LiveKit's Twirp-JSON services (RoomService,
    # Egress). Callers own error handling and timeouts; this only builds the
    # request and signs the short-lived admin token that carries the grants.
    #
    # The destination comes from an admin-editable setting, so requests go
    # through FinalDestination::HTTP: it resolves the host itself, refuses
    # loopback/private/link-local/reserved addresses, and hands only the
    # vetted addresses to the socket layer — re-resolving on every connect,
    # which also covers DNS rebinding.
    module Twirp
      TOKEN_TTL = 1.minute

      Response = Struct.new(:status, :body)

      def self.post(service:, method:, body:, grants:, timeout:)
        uri = URI.parse("#{api_base_url}/twirp/livekit.#{service}/#{method}")

        response =
          FinalDestination::HTTP.start(
            uri.host,
            uri.port,
            use_ssl: uri.scheme == "https",
            open_timeout: timeout,
            read_timeout: timeout,
            write_timeout: timeout,
          ) do |http|
            http.post(
              uri.request_uri,
              body.to_json,
              {
                "Content-Type" => "application/json",
                "Authorization" => "Bearer #{admin_token(grants)}",
              },
            )
          end

        Response.new(response.code.to_i, response.body)
      end

      # The Twirp services listen over HTTP(S) on the same host that serves
      # the SFU's WebSocket signaling.
      def self.api_base_url
        SiteSetting.voice_livekit_url.sub(/\Awss:/, "https:").sub(/\Aws:/, "http:")
      end

      def self.admin_token(grants)
        payload = {
          iss: SiteSetting.voice_livekit_api_key,
          exp: TOKEN_TTL.from_now.to_i,
          video: grants,
        }
        JWT.encode(payload, SiteSetting.voice_livekit_api_secret, "HS256")
      end
    end
  end
end
