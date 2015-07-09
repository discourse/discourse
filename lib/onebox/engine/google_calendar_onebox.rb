module Onebox
  module Engine
    class GoogleCalendarOnebox
      include Engine

      matches_regexp /^(https?:)?\/\/(www\.google\.[\w.]{2,}|goo\.gl)\/calendar\/.+$/
      always_https

      def to_html
        url = @url.split('&').first
        "<iframe src='#{url}&rm=minimal' style='border: 0' width='800' height='600' frameborder='0' scrolling='no' ></iframe>"
      end

    end
  end
end