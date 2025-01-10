# frozen_string_literal: true

require_relative "../mixins/git_blob_onebox"
require_relative "../mixins/github_auth_header"

module Onebox
  module Engine
    class GithubBlobOnebox
      include Onebox::Mixins::GithubAuthHeader

      def self.git_regexp
        %r{^https?://(www\.)?github\.com.*/blob/}
      end

      def self.onebox_name
        "githubblob"
      end

      include Onebox::Mixins::GitBlobOnebox

      def i18n
        {
          binary_file: I18n.t("onebox.github.binary_file"),
          truncated_file: I18n.t("onebox.github.truncated_file"),
          show_original: I18n.t("onebox.github.show_original"),
          requires_iframe: I18n.t("onebox.github.requires_iframe"),
        }
      end

      def raw_regexp
        %r{github\.com/(?<org>[^/]+)/(?<repo>[^/]+)/blob/(?<sha1>[^/]+)/(?<file>[^#]+)(#(L(?<from>[^-]*)(-L(?<to>.*))?))?}mi
      end

      def raw_template(match)
        "https://raw.githubusercontent.com/#{match[:org]}/#{match[:repo]}/#{match[:sha1]}/#{match[:file]}"
      end

      def auth_headers(match)
        github_auth_header(match[:org])
      end

      def data
        super.merge({ domain: "github.com/#{match[:org]}/#{match[:repo]}" })
      end
    end
  end
end
