# frozen_string_literal: true

module Onebox
  module GithubAccess
    def self.token(github_org)
      org_tokens = org_token_map
      (org_tokens[github_org] || org_tokens["default"]).presence
    end

    def self.tokens
      (org_token_map.values.filter_map(&:presence) << nil).uniq
    end

    def self.client(github_org)
      ::Discourse::GithubApi.for(token: token(github_org))
    end

    def self.org_token_map
      tokens = SiteSetting.github_onebox_access_tokens
      return {} if tokens.blank?

      tokens.split("\n").to_h { it.split("|") }
    end
    private_class_method :org_token_map
  end
end
