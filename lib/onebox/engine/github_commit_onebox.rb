module Onebox
  module Engine
    class GithubCommitOnebox
      include Engine
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
        "https://api.github.com/repos/#{match[:owner]}/#{match[:repo]}/commits/#{match[:number]}"
      end

      private

      def match
        @url.match(/github\.com\/(?<owner>[^\/]+)\/(?<repo>[^\/]+)\/commit\/(?<number>[^\/]+)/)
      end

      def data
        {
          url: @url,
          owner: match[:owner],
          repo: match[:repo],
          sha: raw["sha"],
          gravatar: raw["author"]["avatar_url"],
          message: raw["commit"]["message"],
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
