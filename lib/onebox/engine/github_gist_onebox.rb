# frozen_string_literal: true

module Onebox
  module Engine
    class GithubGistOnebox
      include Engine
      include LayoutSupport
      include JSON

      MAX_FILES = 3

      matches_regexp(%r{^http(?:s)?://gist\.(?:(?:\w)+\.)?(github)\.com(?:/)?})
      always_https

      def url
        "https://api.github.com/gists/#{match[:sha]}"
      end

      private

      def data
        @data ||= {
          title: "gist.github.com",
          link: link,
          gist_files: gist_files.take(MAX_FILES),
          truncated_files?: truncated_files?,
        }
      end

      def truncated_files?
        gist_files.size > MAX_FILES
      end

      def gist_files
        return [] unless gist_api

        @gist_files ||= gist_api["files"].values.map { |file_json| GistFile.new(file_json) }
      end

      def gist_api
        @raw ||= raw.clone
      rescue OpenURI::HTTPError
        # The Gist API rate limit of 60 requests per hour was reached.
        nil
      end

      def match
        @match ||= @url.match(%r{gist\.github\.com/([^/]+/)?(?<sha>[0-9a-f]+)})
      end

      class GistFile
        attr_reader :filename
        attr_reader :language

        MAX_LINES = 10

        def initialize(json)
          @json = json
          @filename = @json["filename"]
          @language = @json["language"]
        end

        def content
          lines.take(MAX_LINES).join("\n")
        end

        def truncated?
          lines.size > MAX_LINES
        end

        private

        def lines
          @lines ||= @json["content"].split("\n")
        end
      end
    end
  end
end
