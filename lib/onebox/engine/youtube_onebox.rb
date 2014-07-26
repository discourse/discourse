module Onebox
  module Engine
    class YoutubeOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/(?:www\.)?(?:m\.)?(?:youtube\.com|youtu\.be)\/.+$/)

      # Try to get the video ID. Works for URLs of the form:
      # * https://www.youtube.com/watch?v=Z0UISCEe52Y
      # * http://youtu.be/afyK1HSFfgw
      # * https://www.youtube.com/embed/vsF0K3Ou1v0
      def video_id
        match = @url.match(/^https?:\/\/(?:www\.)?(?:m\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_\-]{11})(?:[#&\?]t=(([0-9]+[smh]?)+))?$/)
        match && match[1]
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
          html = raw[:html] || ""
        end

        rewrite_agnostic(append_params(html))
      end

      def append_params(html)
        result = html.dup
        result.gsub! /(src="[^"]+)/, '\1&wmode=opaque'
        if url =~ /t=(\d+h)?(\d+m)?(\d+s?)?/
          h = Regexp.last_match[1].to_i
          m = Regexp.last_match[2].to_i
          s = Regexp.last_match[3].to_i

          total = (h * 60 * 60) + (m * 60) + s

          result.gsub! /(src="[^"]+)/, '\1&start=' + total.to_s
        end
        result
      end

      def rewrite_agnostic(html)
        html.gsub(/https?:\/\//, '//')
      end
    end
  end
end
