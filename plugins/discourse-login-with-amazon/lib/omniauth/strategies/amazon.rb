# frozen_string_literal: true

module OmniAuth
  module Strategies
    class Amazon < OmniAuth::Strategies::OAuth2
      option :name, "amazon"

      option :client_options,
             {
               site: "https://www.amazon.com/",
               authorize_url: "https://www.amazon.com/ap/oa",
               token_url: "https://api.amazon.com/auth/o2/token",
             }

      option :access_token_options, { mode: :query }

      option :authorize_params, { scope: "profile postal_code" }

      def build_access_token
        token_params = {
          redirect_uri: callback_url.split("?").first,
          client_id: client.id,
          client_secret: client.secret,
        }
        verifier = request.params["code"]
        client.auth_code.get_token(verifier, token_params)
      end

      uid { raw_info["Profile"]["CustomerId"] }

      info do
        { "email" => raw_info["Profile"]["PrimaryEmail"], "name" => raw_info["Profile"]["Name"] }
      end

      extra { { "postal_code" => raw_info["Profile"]["PostalCode"] } }

      def raw_info
        access_token.options[:parse] = :json

        url = "/ap/user/profile"
        params = { params: { access_token: access_token.token } }
        @raw_info ||= access_token.client.request(:get, url, params).parsed
      end

      def callback_url
        origin = ENV["REDIRECT_URL_ORIGIN"] || full_host
        origin + script_name + callback_path
      end
    end
  end
end
