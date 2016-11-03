module Onebox
  module Engine
    class GithubCommitOnebox
      include Engine
      include LayoutSupport
      include JSON

      matches_regexp Regexp.new("^https?://(?:www\.)?(?:(?:\w)+\.)?(github)\.com(?:/)?(?:.)*/commit/")
      always_https

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
        result['title'] = result['commit']['message'].split("\n").first

        if result['commit']['message'].lines.count > 1
          result['message'] = result['commit']['message'].split("\n", 2).last.strip
        end

        ulink = URI(link)
        result['commit_date'] = Time.parse(result['commit']['author']['date']).strftime("%I:%M%p - %d %b %y")
        result['domain'] = "#{ulink.host}/#{ulink.path.split('/')[1]}/#{ulink.path.split('/')[2]}"
        result
      end
    end
  end
end
