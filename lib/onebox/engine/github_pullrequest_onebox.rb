module Onebox
  module Engine
    class GithubPullRequestOnebox
      include Engine
      include LayoutSupport
      include JSON

      matches_regexp Regexp.new("^http(?:s)?://(?:www\\.)?(?:(?:\\w)+\\.)?(github)\\.com(?:/)?(?:.)*/pull/")

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
        result['repository_path'] = "#{URI(link).host}/#{URI(link).path.split('/')[1]}/#{URI(link).path.split('/')[2]}"
        result['repository_url'] = "https://#{result['repository_path']}"
        result
      end
    end
  end
end
