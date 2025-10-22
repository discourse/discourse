# frozen_string_literal: true

require "omniauth-oauth2"

# There is an omniauth-apple gem which we could use here
# But it has many more features than we need, and more surface area for bugs/exploits
#
# This implementation also has a workaround which redirects
# Apple's POST callbacks to GET requests, so that the browser sends SameSite=Lax
# cookies in the request.
#
# We may want to switch to the gem in future, especially if Apple change
# the implementation

module OmniAuth
  module Strategies
    class Apple < OmniAuth::Strategies::OAuth2
      option :name, "apple"

      option :client_options,
             site: "https://appleid.apple.com",
             authorize_url: "/auth/authorize",
             token_url: "/auth/token"

      option :authorize_params, response_mode: "form_post", scope: "email name"

      uid { id_token_info["sub"] }

      info do
        {}.tap do |h|
          h[:email] = id_token_info["email"] if id_token_info["email"]
          h[:first_name] = unsafe_user_info.dig("name", "firstName")
          h[:last_name] = unsafe_user_info.dig("name", "lastName")
          h[:name] = "#{h[:first_name]} #{h[:last_name]}" if h[:first_name] && h[:last_name]
        end
      end

      extra { { raw_info: { id_token_info: id_token_info, id_token: access_token["id_token"] } } }

      def client
        ensure_client_secret
        super
      end

      def callback_url
        full_host + script_name + callback_path
      end

      def callback_phase
        if request.request_method.downcase.to_sym == :post
          url = "#{callback_url}"
          if (code = request.params["code"]) && (state = request.params["state"])
            url += "?code=#{CGI.escape(code)}"
            url += "&state=#{CGI.escape(state)}"
            url += "&user=#{CGI.escape(request.params["user"])}" if request.params["user"]
          end
          session.options[:drop] = true # Do not set a session cookie on this response
          return redirect url
        end
        super
      end

      private

      def id_token_info
        # Verify the claims in the JWT
        # The signature does not need to be verified because the
        # token was acquired via a direct server-server connection to the issuer
        # But we verify it anyway to be double-safe
        @id_token_info ||=
          begin
            id_token = access_token.params["id_token"]
            jwt_options = {
              verify_iss: true,
              iss: "https://appleid.apple.com",
              verify_aud: true,
              aud: options.client_id,
              verify_not_before: true,
              verify_expiration: true,
              algorithms: ["RS256"],
              jwks: options.jwk_fetcher,
            }
            payload, _header = ::JWT.decode(id_token, nil, true, jwt_options)
            payload
          end
      end

      def unsafe_user_info
        @unsafe_user_info ||=
          begin
            JSON.parse(request.params["user"] || "")
          rescue JSON::ParserError
            {}
          end
      end

      def ensure_client_secret
        options[:client_secret] ||= client_secret
      end

      def client_secret
        payload = {
          iss: options.team_id,
          aud: "https://appleid.apple.com",
          sub: options.client_id,
          iat: Time.now.to_i,
          exp: Time.now.to_i + 60,
        }
        headers = { kid: options.key_id }

        ::JWT.encode(payload, ::OpenSSL::PKey::EC.new(options.pem), "ES256", headers)
      end
    end
  end
end
