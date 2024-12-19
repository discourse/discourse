# frozen_string_literal: true

module Onebox
  module Engine
    class XkcdOnebox
      include Engine
      include LayoutSupport
      include JSON

      matches_domain("xkcd.com", "www.xkcd.com", "m.xkcd.com")
      always_https

      def self.matches_path(path)
        path.match?(%r{^/\d+$})
      end

      def url
        "https://xkcd.com/#{match[:comic_id]}/info.0.json"
      end

      private

      def match
        @match ||= @url.match(%{xkcd\.com/(?<comic_id>\\d+)})
      end

      def data
        { link: @url, title: raw["safe_title"], image: raw["img"], description: raw["alt"] }
      end
    end
  end
end
