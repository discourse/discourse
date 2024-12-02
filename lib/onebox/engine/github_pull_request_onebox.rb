# frozen_string_literal: true

require_relative "../mixins/github_body"
require_relative "../mixins/github_auth_header"

module Onebox
  module Engine
    class GithubPullRequestOnebox
      include Engine
      include LayoutSupport
      include JSON
      include Onebox::Mixins::GithubBody
      include Onebox::Mixins::GithubAuthHeader

      matches_regexp(%r{^https?://(?:www\.)?(?:(?:\w)+\.)?(github)\.com(?:/)?(?:.)*/pull})
      always_https

      def url
        "https://api.github.com/repos/#{match[:org]}/#{match[:repository]}/pulls/#{match[:number]}"
      end

      private

      def match
        @match ||=
          @url.match(%r{github\.com/(?<org>[^/]+)/(?<repository>[^/]+)/pull/(?<number>[^/]+)})
      end

      def data
        result = raw(github_auth_header(match[:org])).clone
        result["link"] = link

        created_at = Time.parse(result["created_at"])
        result["created_at"] = created_at.strftime("%I:%M%p - %d %b %y %Z")
        result["created_at_date"] = created_at.strftime("%F")
        result["created_at_time"] = created_at.strftime("%T")

        ulink = URI(link)
        result["domain"] = "#{ulink.host}/#{ulink.path.split("/")[1]}/#{ulink.path.split("/")[2]}"

        result["body"], result["excerpt"] = compute_body(result["body"])

        if result["commit"] = load_commit(link)
          result["body"], result["excerpt"] =
            compute_body(result["commit"]["commit"]["message"].lines[1..].join)
        elsif result["comment"] = load_comment(link)
          result["body"], result["excerpt"] = compute_body(result["comment"]["body"])
        elsif result["discussion"] = load_review(link)
          result["body"], result["excerpt"] = compute_body(result["discussion"]["body"])
        else
          result["pr"] = true
        end
        result["i18n"] = i18n
        result["i18n"]["pr_summary"] = I18n.t(
          "onebox.github.pr_summary",
          {
            commits: result["commits"],
            changed_files: result["changed_files"],
            additions: result["additions"],
            deletions: result["deletions"],
          },
        )
        result["is_private"] = result.dig("base", "repo", "private")

        result
      end

      def i18n
        {
          opened: I18n.t("onebox.github.opened"),
          commit_by: I18n.t("onebox.github.commit_by"),
          comment_by: I18n.t("onebox.github.comment_by"),
          review_by: I18n.t("onebox.github.review_by"),
        }
      end

      def load_commit(link)
        if commit_match = link.match(%r{commits/(\h+)})
          load_json(
            "https://api.github.com/repos/#{match[:org]}/#{match[:repository]}/commits/#{commit_match[1]}",
          )
        end
      end

      def load_comment(link)
        if comment_match = link.match(/#issuecomment-(\d+)/)
          load_json(
            "https://api.github.com/repos/#{match[:org]}/#{match[:repository]}/issues/comments/#{comment_match[1]}",
          )
        end
      end

      def load_review(link)
        if review_match = link.match(/#discussion_r(\d+)/)
          load_json(
            "https://api.github.com/repos/#{match[:org]}/#{match[:repository]}/pulls/comments/#{review_match[1]}",
          )
        end
      end

      def load_json(url)
        ::MultiJson.load(
          URI.parse(url).open({ read_timeout: timeout }.merge(github_auth_header(match[:org]))),
        )
      end
    end
  end
end
