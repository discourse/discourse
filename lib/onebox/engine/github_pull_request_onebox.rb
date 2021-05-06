# frozen_string_literal: true

require_relative '../mixins/github_body'

module Onebox
  module Engine
    class GithubPullRequestOnebox
      include Engine
      include LayoutSupport
      include JSON
      include Onebox::Mixins::GithubBody

      GITHUB_COMMENT_REGEX = /(<!--.*?-->\r\n)/

      matches_regexp(/^https?:\/\/(?:www\.)?(?:(?:\w)+\.)?(github)\.com(?:\/)?(?:.)*\/pull/)
      always_https

      def url
        "https://api.github.com/repos/#{match[:owner]}/#{match[:repository]}/pulls/#{match[:number]}"
      end

      private

      def match
        @match ||= @url.match(%r{github\.com/(?<owner>[^/]+)/(?<repository>[^/]+)/pull/(?<number>[^/]+)})
      end

      def data
        result = raw.clone
        result['link'] = link

        created_at = Time.parse(result['created_at'])
        result['created_at'] = created_at.strftime("%I:%M%p - %d %b %y %Z")
        result['created_at_date'] = created_at.strftime("%F")
        result['created_at_time'] = created_at.strftime("%T")

        ulink = URI(link)
        result['domain'] = "#{ulink.host}/#{ulink.path.split('/')[1]}/#{ulink.path.split('/')[2]}"

        result['body'], result['excerpt'] = compute_body(result['body'])

        result
      end
    end
  end
end
