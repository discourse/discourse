# frozen_string_literal: true

require_relative "../mixins/git_blob_onebox"

module Onebox
  module Engine
    class GitlabBlobOnebox
      def self.git_regexp
        %r{^https?://(www\.)?gitlab\.com.*/blob/}
      end

      def self.onebox_name
        "gitlabblob"
      end

      include Onebox::Mixins::GitBlobOnebox

      def i18n
        {
          truncated_file: I18n.t("onebox.gitlab.truncated_file"),
          show_original: I18n.t("onebox.gitlab.show_original"),
        }
      end

      def raw_regexp
        %r{gitlab\.com/(?<user>[^/]+)/(?<repo>[^/]+)/blob/(?<sha1>[^/]+)/(?<file>[^#]+)(#(L(?<from>[^-]*)(-L(?<to>.*))?))?}mi
      end

      def raw_template(m)
        "https://gitlab.com/#{m[:user]}/#{m[:repo]}/raw/#{m[:sha1]}/#{m[:file]}"
      end

      def auth_headers(_match)
        {}
      end

      def data
        super.merge({ domain: "gitlab.com/#{match[:user]}/#{match[:repo]}" })
      end
    end
  end
end
