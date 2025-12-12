# frozen_string_literal: true

module Onebox
  module Mixins
    module GithubAuthHeader
      def github_auth_header(github_org)
        return {} if SiteSetting.github_onebox_access_tokens.blank?

        org_tokens = SiteSetting.github_onebox_access_tokens.split("\n").to_h { _1.split("|") }

        token = org_tokens[github_org] || org_tokens["default"]

        return {} if token.blank?

        { "Authorization" => "Bearer #{token}" }
      end
    end
  end
end
