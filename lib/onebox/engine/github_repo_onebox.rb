# frozen_string_literal: true

require_relative "../mixins/github_body"
require_relative "../mixins/github_auth_header"

module Onebox
  module Engine
    class GithubRepoOnebox
      include Engine
      include LayoutSupport
      include JSON
      include Onebox::Mixins::GithubAuthHeader

      GITHUB_COMMENT_REGEX = /(<!--.*?-->\r\n)/m

      matches_regexp(%r{^https?:\/\/(?:www\.)?(?!gist\.)[^\/]*github\.com\/[^\/]+\/[^\/]+\/?$})
      always_https

      def url
        "https://api.github.com/repos/#{match[:org]}/#{match[:repository]}"
      end

      private

      def match
        @match ||= @url.match(%r{github\.com/(?<org>[^/]+)/(?<repository>[^/]+)})
      end

      def data
        result = raw(github_auth_header(match[:org])).clone
        result["link"] = link
        description = result["description"]
        title = "GitHub - #{result["full_name"]}"

        if description.blank?
          description = I18n.t("onebox.github.no_description", repo: result["full_name"])
        else
          title += ": #{Onebox::Helpers.truncate(description)}"
        end

        result["description"] = description
        result["title"] = title
        result["is_private"] = result["private"]

        # The SecureRandom part of this doesn't matter, it's just used for caching the
        # repo thumbnail which is generated on the fly by GitHub. There isn't detail
        # in https://github.blog/2021-06-22-framework-building-open-graph-images/,
        # but this SO answer https://stackoverflow.com/a/69043743 suggests this is
        # how it works and testing confirms it.
        result[
          "thumbnail"
        ] = "https://opengraph.githubassets.com/#{SecureRandom.hex}/#{match[:org]}/#{match[:repository]}"
        result
      end
    end
  end
end
