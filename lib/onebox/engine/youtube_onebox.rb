module Onebox
  module Engine
    class YoutubeOnebox
      include Engine
      include StandardEmbed

      matches_regexp /^https?:\/\/(?:www\.)?(?:youtube\.com|youtu\.be)\/.+$/

      def to_html
        rewrite_agnostic(append_params(raw[:html]))
      end

      def append_params(html)
        result = html.dup
        result.gsub! /(src="[^"]+)/, '\1&wmode=opaque'
        if url =~ /t=(\d+)/
          result.gsub! /(src="[^"]+)/, '\1&start=' + Regexp.last_match[1]
        end
        result
      end

      def rewrite_agnostic(html)
        html.gsub(/https?:\/\//, '//')
      end
    end
  end
end
