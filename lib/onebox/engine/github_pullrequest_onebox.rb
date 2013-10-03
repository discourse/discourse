module Onebox
  module Engine
    class GithubPullRequestOnebox
      include Engine
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
        "https://api.github.com/repos/#{match[:owner]}/#{match[:repo]}/pulls/#{match[:number]}"
      end

      private

      def match
        @url.match(/github\.com\/(?<owner>[^\/]+)\/(?<repo>[^\/]+)\/pull\/(?<number>[^\/]+)/)
      end

      def data
        {
          url: @url,
          author: raw["user"]["login"],
          gravatar: raw["user"]["avatar_url"],
          title: raw["title"],
          repo: raw["base"]["repo"]["full_name"],
          time_date: raw["created_at"],
          commits: raw["commits"],
          additions: raw["additions"],
          deletions: raw["deletions"],
          changed_files: raw["changed_files"],
          description: raw["body"]
        }
      end
    end
  end
end
