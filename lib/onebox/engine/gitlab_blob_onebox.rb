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

      def raw_regexp
        %r{gitlab\.com/(?<user>[^/]+)/(?<repo>[^/]+)/blob/(?<sha1>[^/]+)/(?<file>[^#]+)(#(L(?<from>[^-]*)(-L(?<to>.*))?))?}mi
      end

      def raw_template(m)
        "https://gitlab.com/#{m[:user]}/#{m[:repo]}/raw/#{m[:sha1]}/#{m[:file]}"
      end

      def title
        Sanitize.fragment(Onebox::Helpers.uri_unencode(link).sub(%r{^https?\://gitlab\.com/}, ""))
      end
    end
  end
end
