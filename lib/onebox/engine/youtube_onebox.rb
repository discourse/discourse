module Onebox
  module Engine
    class YoutubeOnebox
      include Engine
      include StandardEmbed

      matches_regexp /^https?:\/\/(?:www\.)?(?:youtube\.com|youtu\.be)\/.+$/

      def to_html
        rewrite_agnostic(append_embed_wmode(raw[:html]))
      end

      def append_embed_wmode(html)
        html.gsub /(src="[^"]+)/, '\1&wmode=opaque'
      end

      def rewrite_agnostic(html)
        html.gsub(/https?:\/\//, '//')
      end
    end
  end
end
