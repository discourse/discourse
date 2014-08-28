module Onebox
  module Engine
    class TwitterStatusOnebox
      include Engine
      include JSON

      matches_regexp Regexp.new("^http(?:s)?://(?:www\\.)?(?:(?:\\w)+\\.)?(twitter)\\.com(?:/)?(?:.)*/status(es)?/")

      def url
        "https://api.twitter.com/1/statuses/oembed.json?id=#{match[:id]}"
      end

      def to_html
        raw['html']
      end

      private

      def match
        @match ||= @url.match(%r{twitter\.com/.+?/status(es)?/(?<id>\d+)})
      end
    end
  end
end
