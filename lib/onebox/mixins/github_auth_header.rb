# frozen_string_literal: true

module Onebox
  module Mixins
    module GithubAuthHeader
      def github_auth_header
        return {} if SiteSetting.github_onebox_access_token.blank?
        { "Authorization" => "Bearer #{SiteSetting.github_onebox_access_token}" }
      end
    end
  end
end
