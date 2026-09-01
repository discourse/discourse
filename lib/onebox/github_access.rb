# frozen_string_literal: true

module Onebox
  module GithubAccess
    class << self
      def token(github_org)
        org_tokens = org_token_map
        (org_tokens[github_org] || org_tokens["default"]).presence
      end

      def tokens
        (org_token_map.values.filter_map(&:presence) << nil).uniq
      end

      def client(github_org)
        ::Discourse::GithubApi.for(token: token(github_org))
      end

      def org_token_map
        tokens = SiteSetting.github_onebox_access_tokens
        return {} if tokens.blank?

        tokens.split("\n").to_h { it.split("|") }
      end
    end
    private_class_method :org_token_map
  end
end
