# frozen_string_literal: true

module Onebox
  module Engine
    class AsciinemaOnebox
      include Engine
      include StandardEmbed

      always_https
      matches_regexp(/^https?:\/\/asciinema\.org\/a\/[\p{Alnum}_\-]+$/)
      requires_iframe_origins "https://asciinema.org"

      def to_html
        "<iframe src='https://asciinema.org/a/#{match[:asciinema_id]}/iframe' width='100%' height='530px' frameborder='0' style='border:0' async>"
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
