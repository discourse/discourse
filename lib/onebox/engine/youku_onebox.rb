module Onebox
  module Engine
    class YoukuOnebox
      include Engine
      include HTML

      matches_regexp(/^(https?:\/\/)?([\da-z\.-]+)(youku.com\/)(.)+\/?$/)

      # Try to get the video ID. Works for URLs of the form:
      # * http://v.youku.com/v_show/id_XNjM3MzAxNzc2.html
      def video_id
        match = uri.path.match(/\/v_show\/id_([a-zA-Z0-9]*)(\.html)*/)
        return match[1] if match && match[1]

        nil
      rescue
        return nil
      end

      def to_html
        "<iframe width='480' height='270' src='http://player.youku.com/embed/#{video_id}' frameborder='0' allowfullscreen></iframe>"
      end

      def placeholder_html
        if video_id
          meta_url = "http://v.youku.com/player/getPlayList/VideoIDS/#{video_id}"
          response = Onebox::Helpers.fetch_response(meta_url)
          meta = MultiJson::load(response.body) if response && response.body
          image_src = if meta && meta['data'] && meta['data'][0] && meta['data'][0]['logo']
                        meta['data'][0]['logo']
                      else
                        nil
                      end
          "<img src='#{image_src}' width='480' height='270'>"
        else
          to_html
        end
      end

      private

      # Note: May throw! Make sure to recue.
      def uri
        @_uri ||= URI(@url)
      end

    end 
  end 
end
