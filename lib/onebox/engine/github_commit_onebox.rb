# frozen_string_literal: true

require_relative '../mixins/github_body'

module Onebox
  module Engine
    class GithubCommitOnebox
      include Engine
      include LayoutSupport
      include JSON
      include Onebox::Mixins::GithubBody

      matches_regexp(/^https?:\/\/(?:www\.)?(?:(?:\w)+\.)?(github)\.com(?:\/)?(?:.)*\/commit\//)
      always_https

      def url
        "https://api.github.com/repos/#{match[:owner]}/#{match[:repository]}/commits/#{match[:sha]}"
      end

      private

      def match
        return @match if defined?(@match)

        @match = @url.match(%{github\.com/(?<owner>[^/]+)/(?<repository>[^/]+)/commit/(?<sha>[^/]+)})
        @match ||= @url.match(%{github\.com/(?<owner>[^/]+)/(?<repository>[^/]+)/pull/(?<pr>[^/]+)/commit/(?<sha>[^/]+)})

        @match
      end

      def data
        result = raw.clone

        lines = result['commit']['message'].split("\n")
        result['title'] = lines.first
        result['body'], result['excerpt'] = compute_body(lines[1..lines.length].join("\n"))

        committed_at = Time.parse(result['commit']['author']['date'])
        result['committed_at'] = committed_at.strftime("%I:%M%p - %d %b %y %Z")
        result['committed_at_date'] = committed_at.strftime("%F")
        result['committed_at_time'] = committed_at.strftime("%T")

        result['link'] = link
        ulink = URI(link)
        result['domain'] = "#{ulink.host}/#{ulink.path.split('/')[1]}/#{ulink.path.split('/')[2]}"

        result
      end
    end
  end
end
