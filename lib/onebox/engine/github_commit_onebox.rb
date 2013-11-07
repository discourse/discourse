module Onebox
  module Engine
    class GithubCommitOnebox
      include Engine
      include LayoutSupport
      include JSON

      matches do
        http
        maybe("www.")
        domain("github")
        tld("com")
        anything
        with("/commit/")
      end

      def url
        "https://api.github.com/repos/#{match[:owner]}/#{match[:repository]}/commits/#{match[:sha]}"
      end

      private

      def match
        @match ||= @url.match(/github\.com\/(?<owner>[^\/]+)\/(?<repository>[^\/]+)\/commit\/(?<sha>[^\/]+)/)
      end

      def data
        {
          link: link,
          domain: "http://www.github.com",
          badge: "g",
          owner: match[:owner],
          repository: match[:repository],
          sha: raw["sha"],
          gravatar: raw["author"]["avatar_url"],
          title: raw["commit"]["message"],
          author: raw["author"]["login"],
          time_date: raw["commit"]["committer"]["date"],
          files_changed: raw["files"].length,
          additions: raw["stats"]["additions"],
          deletions: raw["stats"]["deletions"]
        }
      end
    end
  end
end
