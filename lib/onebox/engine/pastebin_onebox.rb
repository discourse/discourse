module Onebox
  module Engine
    class PastebinOnebox
      include Engine
      include LayoutSupport

      MAX_LINES = 10

      matches_regexp(/^http?:\/\/pastebin\.com/)

      private

      def data
        @data ||= {
          title: 'pastebin.com',
          link: link,
          content: content,
          truncated?: truncated?
        }
      end

      def content
        lines.take(MAX_LINES).join("\n")
      end

      def truncated?
        lines.size > MAX_LINES
      end

      def lines
        return @lines if @lines
        response = Onebox::Helpers.fetch_response("http://pastebin.com/raw/#{paste_key}", 1) rescue ""
        @lines = response.split("\n")
      end

      def paste_key
        if uri.path =~ /\/raw\//
          match = uri.path.match(/\/raw\/([^\/]+)/)
          return match[1] if match && match[1]
        elsif uri.path =~ /\/download\//
          match = uri.path.match(/\/download\/([^\/]+)/)
          return match[1] if match && match[1]
        elsif uri.path =~ /\/embed\//
          match = uri.path.match(/\/embed\/([^\/]+)/)
          return match[1] if match && match[1]
        else
          match = uri.path.match(/\/([^\/]+)/)
          return match[1] if match && match[1]
        end

        nil
      rescue
        return nil
      end
    end
  end
end
