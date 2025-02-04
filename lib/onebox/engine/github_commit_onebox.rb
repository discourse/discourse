# frozen_string_literal: true

require_relative "../mixins/github_body"
require_relative "../mixins/github_auth_header"

module Onebox
  module Engine
    class GithubCommitOnebox
      include Engine
      include LayoutSupport
      include JSON
      include Onebox::Mixins::GithubBody
      include Onebox::Mixins::GithubAuthHeader

      matches_domain("github.com", "www.github.com")
      always_https

      def self.matches_path(path)
        path.match?(%r{^/[\w\-]+/[\w\-]+/commit/[a-f0-9]{40}$})
      end

      def url
        "https://api.github.com/repos/#{match[:org]}/#{match[:repository]}/commits/#{match[:sha]}"
      end

      private

      def match
        return @match if defined?(@match)

        @match = @url.match(%{github\.com/(?<org>[^/]+)/(?<repository>[^/]+)/commit/(?<sha>[^/]+)})
        @match ||=
          @url.match(
            %{github\.com/(?<org>[^/]+)/(?<repository>[^/]+)/pull/(?<pr>[^/]+)/commit/(?<sha>[^/]+)},
          )

        @match
      end

      def data
        result = raw(github_auth_header(match[:org])).clone

        lines = result["commit"]["message"].split("\n")
        result["title"] = lines.first
        result["body"], result["excerpt"] = compute_body(lines[1..lines.length].join("\n"))

        committed_at = Time.parse(result["commit"]["committer"]["date"])
        result["committed_at"] = committed_at.strftime("%I:%M%p - %d %b %y %Z")
        result["committed_at_date"] = committed_at.strftime("%F")
        result["committed_at_time"] = committed_at.strftime("%T")

        result["link"] = link
        ulink = URI(link)
        result["domain"] = "#{ulink.host}/#{ulink.path.split("/")[1]}/#{ulink.path.split("/")[2]}"
        result["i18n"] = { committed: I18n.t("onebox.github.committed") }

        result
      end
    end
  end
end
