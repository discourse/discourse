# frozen_string_literal: true

require "open-uri"
require_relative "../github_access"

module Onebox
  module Mixins
    module GithubApi
      class GithubRateLimited < OpenURI::HTTPError
        def initialize(message = "GitHub API rate limit backoff is active")
          super(message, nil)
        end
      end

      def load_json(url, github_org = match_org)
        github_fetch(url, Onebox::GithubAccess.client(github_org))
      end

      def github_token?(github_org = match_org)
        Onebox::GithubAccess.token(github_org).present?
      end

      private

      def raw
        @raw ||= load_json(url)
      end

      def match_org
        match.names.include?("org") ? match[:org] : nil
      end

      def github_fetch(url, client)
        client.get(url)
      rescue ::Discourse::GithubApi::RateLimited
        raise GithubRateLimited
      rescue ::Discourse::GithubApi::Error => e
        raise OpenURI::HTTPError.new(e.message, nil)
      end
    end
  end
end
