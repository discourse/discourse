# frozen_string_literal: true

module Onebox
  module Mixins
    module GithubAuthHeader
      def github_auth_header
        if SiteSetting.github_onebox_access_token.present?
          { "Authorization" => "Bearer #{SiteSetting.github_onebox_access_token}" }
        else
          {}
        end
      end
    end
  end
end
