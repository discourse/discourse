module Onebox
  module Engine
    class GithubCommitOnebox
      include Engine
      include LayoutSupport
      include JSON

      matches_regexp Regexp.new("^http(?:s)?://(?:www\.)?(?:(?:\w)+\.)?(github)\.com(?:/)?(?:.)*/commit/")

      def url
        "https://api.github.com/repos/#{match[:owner]}/#{match[:repository]}/commits/#{match[:sha]}"
      end

      private

      def match
        @match ||= @url.match(%{github\.com/(?<owner>[^/]+)/(?<repository>[^/]+)/commit/(?<sha>[^/]+)})
      end

      def data
        result = raw.clone
        result['link'] = link
        result['title'] = result['commit']['message']
        result['commit_date'] = Time.parse(result['commit']['author']['date']).strftime("%I:%M%p - %d %b %y")
        result
      end
    end
  end
end
