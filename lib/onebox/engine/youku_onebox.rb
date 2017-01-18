module Onebox
  module Engine
    class YoukuOnebox
      include Engine
      include HTML

      matches_regexp(/^(https?:\/\/)?([\da-z\.-]+)(youku.com\/)(.)+\/?$/)

      # Try to get the video ID. Works for URLs of the form:
      # * http://v.youku.com/v_show/id_XNjM3MzAxNzc2.html
      # * http://v.youku.com/v_show/id_XMTQ5MjgyMjMyOA==.html?from=y1.3-tech-index3-232-10183.89969-89963.3-1
      def video_id
        match = uri.path.match(/\/v_show\/id_([a-zA-Z0-9_=\-]+)(\.html)?.*/)
        match && match[1]
      rescue
        nil
      end

      def to_html
        "<embed width='570' height='360' src='https://players.youku.com/player.php/sid/#{video_id}/v.swf' type='application/x-shockwave-flash'></embed>"
      end

      private

      def uri
        @_uri ||= URI(@url)
      end

    end
  end
end
