# frozen_string_literal: true

module Voice
  module Livekit
    # Verifies LiveKit webhook deliveries. The Authorization header carries a
    # short-lived HS256 JWT signed with the API secret whose `sha256` claim is
    # the base64 digest of the exact request body — checking it makes the
    # payload itself tamper-proof, not just the token's claims.
    class WebhookVerifier
      class VerificationError < StandardError
      end

      class << self
        def verify!(authorization:, body:)
          raise VerificationError, "LiveKit is not configured" if !Livekit.configured?

          token = authorization.to_s.delete_prefix("Bearer ").strip
          raise VerificationError, "missing Authorization token" if token.blank?

          begin
            claims, _headers =
              JWT.decode(token, SiteSetting.voice_livekit_api_secret, true, algorithm: "HS256")
          rescue JWT::DecodeError => e
            raise VerificationError, "invalid token (#{e.class})"
          end

          if claims["iss"] != SiteSetting.voice_livekit_api_key
            raise VerificationError, "token issued for a different API key"
          end

          digest = Digest::SHA256.base64digest(body)
          if !ActiveSupport::SecurityUtils.secure_compare(claims["sha256"].to_s, digest)
            raise VerificationError, "body hash mismatch"
          end

          true
        end
      end
    end
  end
end
