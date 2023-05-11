# frozen_string_literal: true

require_relative "../mixins/git_blob_onebox"

module Onebox
  module Engine
    class GithubBlobOnebox
      def self.git_regexp
        %r{^https?://(www\.)?github\.com.*/blob/}
      end

      def self.onebox_name
        "githubblob"
      end

      include Onebox::Mixins::GitBlobOnebox

      def raw_regexp
        %r{github\.com/(?<user>[^/]+)/(?<repo>[^/]+)/blob/(?<sha1>[^/]+)/(?<file>[^#]+)(#(L(?<from>[^-]*)(-L(?<to>.*))?))?}mi
      end

      def raw_template(m)
        "https://raw.githubusercontent.com/#{m[:user]}/#{m[:repo]}/#{m[:sha1]}/#{m[:file]}"
      end

      def title
        Sanitize.fragment(Onebox::Helpers.uri_unencode(link).sub(%r{^https?\://github\.com/}, ""))
      end
    end
  end
end
