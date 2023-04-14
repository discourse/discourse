# frozen_string_literal: true

module Onebox
  module Engine
    class PastebinOnebox
      include Engine
      include LayoutSupport

      MAX_LINES = 10

      matches_regexp(%r{^http?://pastebin\.com})

      private

      def data
        @data ||= { title: "pastebin.com", link: link, content: content, truncated?: truncated? }
      end

      def content
        lines.take(MAX_LINES).join("\n")
      end

      def truncated?
        lines.size > MAX_LINES
      end

      def lines
        return @lines if defined?(@lines)
        response =
          begin
            Onebox::Helpers.fetch_response(
              "http://pastebin.com/raw/#{paste_key}",
              redirect_limit: 1,
            )
          rescue StandardError
            ""
          end
        @lines = response.split("\n")
      end

      def paste_key
        regex =
          case uri
          when %r{/raw/}
            %r{/raw/([^/]+)}
          when %r{/download/}
            %r{/download/([^/]+)}
          when %r{/embed/}
            %r{/embed/([^/]+)}
          else
            %r{/([^/]+)}
          end

        match = uri.path.match(regex)
        match[1] if match && match[1]
      end
    end
  end
end
