# frozen_string_literal: true

require_relative "../mixins/github_body"

module Onebox
  module Engine
    class GithubIssueOnebox
      #Author Lidlanca 2014
      include Engine
      include LayoutSupport
      include JSON
      include Onebox::Mixins::GithubBody

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

      def data
        created_at = Time.parse(raw["created_at"])
        closed_at = Time.parse(raw["closed_at"]) if raw["closed_at"]
        body, excerpt = compute_body(raw["body"])
        ulink = URI(link)

        labels = raw["labels"].map { |l| { name: Emoji.codes_to_img(l["name"]) } }

        {
          link: @url,
          title: raw["title"],
          body: body,
          excerpt: excerpt,
          labels: labels,
          user: raw["user"],
          created_at: created_at.strftime("%I:%M%p - %d %b %y %Z"),
          created_at_date: created_at.strftime("%F"),
          created_at_time: created_at.strftime("%T"),
          closed_at: closed_at&.strftime("%I:%M%p - %d %b %y %Z"),
          closed_at_date: closed_at&.strftime("%F"),
          closed_at_time: closed_at&.strftime("%T"),
          closed_by: raw["closed_by"],
          avatar: "https://avatars1.githubusercontent.com/u/#{raw["user"]["id"]}?v=2&s=96",
          domain: "#{ulink.host}/#{ulink.path.split("/")[1]}/#{ulink.path.split("/")[2]}",
        }
      end
    end
  end
end
