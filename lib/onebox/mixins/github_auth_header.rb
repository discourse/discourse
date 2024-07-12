# frozen_string_literal: true

module Onebox
  module Mixins
    module GithubAuthHeader
      def github_auth_header(github_org)
        return {} if SiteSetting.github_onebox_access_tokens.blank?
        org_tokens =
          SiteSetting.github_onebox_access_tokens.split("\n").map { |line| line.split("|") }.to_h

        # Use the default token if no token is found for the org,
        # this will be the token that used to be stored in the old
        # github_onebox_access_token site setting if it was configured.
        token = org_tokens[github_org] || org_tokens["default"]
        return {} if token.blank?

        { "Authorization" => "Bearer #{token}" }
      end
    end
  end
end
