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

      matches_domain("github.com", "www.github.com")
      always_https

      def self.matches_path(path)
        path.match?(%r{.*/pull})
      end

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
        result["pr_status"] = fetch_pr_status(result)
        result["pr_status_title"] = pr_status_title(result["pr_status"])

        created_at = Time.parse(result["created_at"])
        result["created_at"] = created_at.strftime("%I:%M%p - %d %b %y %Z")
        result["created_at_date"] = created_at.strftime("%F")
        result["created_at_time"] = created_at.strftime("%T")

        ulink = URI(link)
        _, org, repo = ulink.path.split("/")
        result["domain"] = "#{ulink.host}/#{org}/#{repo}"

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

        result["base"]["label"].sub!(/\A#{org}:/, "")
        result["head"]["label"].sub!(/\A#{org}:/, "")

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

      def pr_status_title(status)
        key = status.presence || "default"
        I18n.t("onebox.github.pr_title.#{key}")
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
      rescue OpenURI::HTTPError => e
        Rails.logger.warn("GitHub API error: #{e.io.status[0]} fetching #{url}")
        raise
      end

      def fetch_pr_status(pr_data)
        return unless SiteSetting.github_pr_status_enabled

        return "merged" if pr_data["merged"]
        return "closed" if pr_data["state"] == "closed"
        return "draft" if pr_data["draft"]

        reviews_data = load_json(url + "/reviews")

        return "approved" if reviews_approved?(reviews_data)

        "open"
      rescue StandardError => e
        Rails.logger.warn("GitHub PR status fetch error: #{e.message}")
        nil
      end

      def reviews_approved?(reviews)
        return false if reviews.blank?

        states =
          reviews
            .reject { |r| r.dig("user", "id").nil? || %w[PENDING COMMENTED].include?(r["state"]) }
            .group_by { |r| r.dig("user", "id") }
            .transform_values { |rs| rs.max_by { |r| r["submitted_at"] }["state"] }
            .values

        return false if states.empty?

        states.all? { |s| %w[APPROVED DISMISSED].include?(s) } && states.include?("APPROVED")
      end
    end
  end
end
