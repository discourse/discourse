require 'json'

module Onebox
  module Engine
    class AmazonOnebox
      include Engine
      include LayoutSupport
      include HTML


      matches_regexp(/^https?:\/\/(?:www)\.amazon\.(?<tld>com|ca|de|it|es|fr|co\.jp|co\.uk|cn|in|com\.br)\//)

      def url
        return "http://www.amazon.#{tld}/gp/aw/d/" + URI::encode(match[:id]) if match && match[:id]
        @url
      end

      def tld
        @tld || @@matcher.match(@url)["tld"]
      end

      def http_params
        {'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 5_0_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9A405 Safari/7534.48.3'}
      end

      private

      def match
        @match ||= @url.match(/(?:d|g)p\/(?:product\/)?(?<id>[^\/]+)(?:\/|$)/mi)
      end

      def image
        case
        when raw.css("#main-image").any?
          ::JSON.parse(
            raw.css("#main-image").first
              .attributes["data-a-dynamic-image"]
              .value
          ).keys.first
        when raw.css("#landingImage").any?
          raw.css("#landingImage").first["src"]
        end
      end

      def data
        result = { link: link,
                   title: raw.css("title").inner_text,
                   image: image,
                   price: raw.css("#priceblock_ourprice").inner_text }

        result[:by_info] = raw.at("#by-line")
        result[:by_info] = Onebox::Helpers.clean(result[:by_info].inner_html) if result[:by_info]

        summary = raw.at("#productDescription")
        result[:description] = summary.inner_text if summary
        result
      end
    end
  end
end
