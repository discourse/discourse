# frozen_string_literal: true

module Onebox
  module Engine
    class YoukuOnebox
      include Engine
      include HTML

      matches_domain("youku.com", "youku.tv", allow_subdomains: true)
      always_https

      requires_iframe_origins "https://player.youku.com"

      # Try to get the video ID. Works for URLs of the form:
      # * http://v.youku.com/v_show/id_XNjM3MzAxNzc2.html
      # * http://v.youku.com/v_show/id_XMTQ5MjgyMjMyOA==.html?from=y1.3-tech-index3-232-10183.89969-89963.3-1
      def video_id
        match = uri.path.match(%r{/v_show/id_([a-zA-Z0-9_=\-]+)(\.html)?.*})
        match && match[1]
      rescue StandardError
        nil
      end

      def to_html
        <<~HTML
          <iframe
            src="https://player.youku.com/embed/#{video_id}"
            width="640"
            height="430"
            frameborder='0'
            allowfullscreen
          ></iframe>
        HTML
      end
    end
  end
end
