# frozen_string_literal: true

module Onebox
  module Engine
    class AsciinemaOnebox
      include Engine
      include StandardEmbed

      always_https
      matches_regexp(/^https?:\/\/asciinema\.org\/a\/[\p{Alnum}_\-]+$/)

      def to_html
        "<script type='text/javascript' src='https://asciinema.org/a/#{match[:asciinema_id]}.js' id='asciicast-#{match[:asciinema_id]}' async></script>"
      end

      def placeholder_html
        "<img src='https://asciinema.org/a/#{match[:asciinema_id]}.png'>"
      end

      private

      def match
        @match ||= @url.match(/asciinema\.org\/a\/(?<asciinema_id>[\p{Alnum}_\-]+)$/)
      end
    end
  end
end
