# frozen_string_literal: true

module Onebox
  module Engine
    class GithubCommitOnebox
      include Engine
      include LayoutSupport
      include JSON

      matches_regexp Regexp.new("^https?://(?:www\.)?(?:(?:\w)+\.)?(github)\.com(?:/)?(?:.)*/commits?/")
      always_https

      def url
        "https://api.github.com/repos/#{match[:owner]}/#{match[:repository]}/commits/#{match[:sha]}"
      end

      private

      def match
        return @match if @match

        @match = @url.match(%{github\.com/(?<owner>[^/]+)/(?<repository>[^/]+)/commits?/(?<sha>[^/]+)})

        @match = @url.match(%{github\.com/(?<owner>[^/]+)/(?<repository>[^/]+)/pull/(?<pr>[^/]+)/commits?/(?<sha>[^/]+)}) if @match.nil?

        @match
      end

      def data
        result = raw.clone
        result['link'] = link
        result['title'] = result['commit']['message'].split("\n").first

        if result['commit']['message'].lines.count > 1
          message = result['commit']['message'].split("\n", 2).last.strip

          message_words = message.gsub("\n\n", "\n").gsub("\n", "<br>").split(" ")
          max_words = 20
          result['message'] =  message_words[0..max_words].join(" ")
          result['message'] << "..." if message_words.length > max_words
          result['message'] = result['message'].gsub("<br>", "\n")
        end

        ulink = URI(link)
        result['commit_date'] = Time.parse(result['commit']['author']['date']).strftime("%I:%M%p - %d %b %y %Z")
        result['domain'] = "#{ulink.host}/#{ulink.path.split('/')[1]}/#{ulink.path.split('/')[2]}"
        result
      end
    end
  end
end
