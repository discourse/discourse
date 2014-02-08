module Onebox
  module Engine
    class YoutubeOnebox
      include Engine
      include StandardEmbed

      matches_regexp /^https?:\/\/(?:www\.)?(?:youtube\.com|youtu\.be)\/.+$/

      # Try to get the video ID. Works for URLs of the form:
      # * https://www.youtube.com/watch?v=Z0UISCEe52Y
      # * http://youtu.be/afyK1HSFfgw
      def video_id
        match = @url.match(/^https?:\/\/(www\.)?(youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_\-]{11})$/)
        match && match[3]
      end

      def placeholder_html
        if video_id
          "<img src='http://i1.ytimg.com/vi/#{video_id}/hqdefault.jpg' width='480' height='270'>"
        else
          to_html
        end
      end

      def to_html
        if video_id
          # Avoid making HTTP requests if we are able to get the video ID from the
          # URL.
          html = "<iframe width=\"480\" height=\"270\" src=\"https://www.youtube.com/embed/#{video_id}?feature=oembed\" frameborder=\"0\" allowfullscreen></iframe>"
        else
          # Fall back to making HTTP requests.
          html = raw[:html]
        end

        rewrite_agnostic(append_params(html))
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
