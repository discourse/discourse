# frozen_string_literal: true

module Onebox
  module Mixins
    module RedditAuthHeader
      def reddit_auth_header
        if SiteSetting.reddit_onebox_client_id.blank? ||
             SiteSetting.reddit_onebox_client_secret.blank?
          return {}
        end

        token = fetch_reddit_access_token
        return {} if token.blank?

        { "Authorization" => "Bearer #{token}" }
      end

      def reddit_authenticated?
        SiteSetting.reddit_onebox_client_id.present? &&
          SiteSetting.reddit_onebox_client_secret.present?
      end

      private

      def fetch_reddit_access_token
        Discourse
          .cache
          .fetch("reddit_onebox_access_token", expires_in: 50.minutes) do
            user = SiteSetting.reddit_onebox_client_id
            password = SiteSetting.reddit_onebox_client_secret

            response =
              Excon.post(
                "https://www.reddit.com/api/v1/access_token",
                body: URI.encode_www_form(grant_type: "client_credentials"),
                headers: {
                  "Content-Type" => "application/x-www-form-urlencoded",
                  "User-Agent" => Onebox::Helpers.user_agent,
                },
                user:,
                password:,
              )

            ::MultiJson.load(response.body)["access_token"] if response.status == 200
          end
      end
    end
  end
end
