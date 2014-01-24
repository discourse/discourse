module Onebox
  module Engine
    class GithubPullRequestOnebox
      include Engine
      include LayoutSupport
      include JSON

      matches do
        http
        maybe("www.")
        domain("github")
        tld("com")
        anything
        with("/pull/")
      end

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
        result['created_at'] = Time.parse(result['created_at']).strftime("%I:%M%p - %d %b %y")
        result
      end
    end
  end
end
