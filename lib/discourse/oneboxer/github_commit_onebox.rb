module Discourse
  module Oneboxer
    class GithubCommitOnebox < HandlebarsOnebox

      matcher /^https?:\/\/(?:www\.)?github\.com\/[^\/]+\/[^\/]+\/commit\/.+/
      favicon 'github.png'

      def translate_url
        m = @url.match(/github\.com\/(?<owner>[^\/]+)\/(?<repo>[^\/]+)\/commit\/(?<sha>[^\/]+)/mi)
        return "https://api.github.com/repos/#{m[:owner]}/#{m[:repo]}/commits/#{m[:sha]}" if m.to_a.any?
        @url
      end

      def parse(data)
        result = MultiJson.load(data)

        result['commit_date'] = Time.parse(result['commit']['author']['date']).strftime("%I:%M%p - %d %b %y")

        result
      end

    end
  end
end
