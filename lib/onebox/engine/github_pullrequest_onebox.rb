module Onebox
  module Engine
    class GithubPullRequestOnebox
      include Engine
      include LayoutSupport
      include JSON

      matches_regexp Regexp.new("^https?://(?:www\\.)?(?:(?:\\w)+\\.)?(github)\\.com(?:/)?(?:.)*/pull/")
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
        result['created_at'] = Time.parse(result['created_at']).strftime("%I:%M%p - %d %b %y")
        ulink = URI(link)
        result['domain'] = "#{ulink.host}/#{ulink.path.split('/')[1]}/#{ulink.path.split('/')[2]}"
        result
      end
    end
  end
end
