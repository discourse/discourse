# frozen_string_literal: true

require_relative "../mixins/github_body"
require_relative "../mixins/github_auth_header"

module Onebox
  module Engine
    class GithubIssueOnebox
      #Author Lidlanca 2014
      include Engine
      include LayoutSupport
      include JSON
      include Onebox::Mixins::GithubBody
      include Onebox::Mixins::GithubAuthHeader

      matches_regexp(
        %r{^https?://(?:www\.)?(?:(?:\w)+\.)?github\.com/(?<org>.+)/(?<repo>.+)/issues/([[:digit:]]+)},
      )
      always_https

      def url
        m = match
        "https://api.github.com/repos/#{m["org"]}/#{m["repo"]}/issues/#{m["item_id"]}"
      end

      private

      def match
        @match ||=
          @url.match(
            %r{^http(?:s)?://(?:www\.)?(?:(?:\w)+\.)?github\.com/(?<org>.+)/(?<repo>.+)/(?<type>issues)/(?<item_id>[\d]+)},
          )
      end

      def i18n
        { opened: I18n.t("onebox.github.opened"), closed: I18n.t("onebox.github.closed") }
      end

      def data
        result = raw(github_auth_header).clone
        created_at = Time.parse(result["created_at"])
        closed_at = Time.parse(result["closed_at"]) if result["closed_at"]
        body, excerpt = compute_body(result["body"])
        ulink = URI(link)

        labels =
          result["labels"].map do |l|
            { name: Emoji.codes_to_img(Onebox::Helpers.sanitize(l["name"])) }
          end

        {
          link: @url,
          title: result["title"],
          body: body,
          excerpt: excerpt,
          labels: labels,
          user: result["user"],
          created_at: created_at.strftime("%I:%M%p - %d %b %y %Z"),
          created_at_date: created_at.strftime("%F"),
          created_at_time: created_at.strftime("%T"),
          closed_at: closed_at&.strftime("%I:%M%p - %d %b %y %Z"),
          closed_at_date: closed_at&.strftime("%F"),
          closed_at_time: closed_at&.strftime("%T"),
          closed_by: result["closed_by"],
          avatar: "https://avatars1.githubusercontent.com/u/#{result["user"]["id"]}?v=2&s=96",
          domain: "#{ulink.host}/#{ulink.path.split("/")[1]}/#{ulink.path.split("/")[2]}",
          i18n: i18n,
        }
      end
    end
  end
end
