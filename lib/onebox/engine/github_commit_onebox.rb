module Onebox
  module Engine
    class GithubCommitOnebox
      include Engine
      include HTML

      matches do
        http
        maybe("www.")
        domain("github")
        tld("com")
        anything
        with("/commit/")
      end

      private

      def data
        {
          url: @url,
          owner: raw.css(".entry-title .author .url").inner_text,
          repo: raw.css(".entry-title .js-current-repository").inner_text,
          sha: raw.css(".sha").inner_text,
          branch: raw.css(".commit-branches .branches-list .branch a").inner_text,
          gravatar: raw.css(".gravatar").first["src"],
          message: raw.css(".commit-title").inner_text,
          description: raw.css(".commit-desc").inner_text,
          author: raw.css(".author-name a").inner_text,
          time_date: raw.css(".js-relative-date").first["title"],
          diff_stats: raw.css(".details-collapse .explain").inner_text
        }
      end
    end
  end
end
