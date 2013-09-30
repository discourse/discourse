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

      private

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
