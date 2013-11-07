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
        @match ||= @url.match(/github\.com\/(?<owner>[^\/]+)\/(?<repository>[^\/]+)\/pull\/(?<number>[^\/]+)/)
      end

      def data
        {
          link: link,
          domain: "http://www.github.com",
          badge: "g",
          author: raw["user"]["login"],
          gravatar: raw["user"]["avatar_url"],
          title: raw["title"],
          repository: raw["base"]["repo"]["full_name"],
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
