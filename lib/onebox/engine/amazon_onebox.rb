require 'json'

module Onebox
  module Engine
    class AmazonOnebox
      include Engine
      include LayoutSupport
      include HTML

      always_https
      matches_regexp(/^https?:\/\/(?:www\.)?(?:smile\.)?(amazon|amzn)\.(?<tld>com|ca|de|it|es|fr|co\.jp|co\.uk|cn|in|com\.br)\//)

      def url
        if match && match[:id]
          return "https://www.amazon.#{tld}/gp/aw/d/#{URI::encode(match[:id])}"
        end

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
        if (main_image = raw.css("#main-image")) && main_image.any?
          attributes = main_image.first.attributes

          return attributes["data-a-hires"] if attributes["data-a-hires"]

          if attributes["data-a-dynamic-image"]
            return ::JSON.parse(attributes["data-a-dynamic-image"].value).keys.first
          end
        end

        if (landing_image = raw.css("#landingImage")) && landing_image.any?
          landing_image.first["src"]
        end
      end

      def data
        result = { link: link,
                   title: CGI.unescapeHTML(raw.css("title").inner_text),
                   image: image }

        result[:by_info] = raw.at("#by-line")
        result[:by_info] = Onebox::Helpers.clean(result[:by_info].inner_html) if result[:by_info]

        # get item price (Amazon markup is inconsistent, deal with it)
        result[:price] =
          if raw.css("#priceblock_ourprice .restOfPrice")[0] && raw.css("#priceblock_ourprice .restOfPrice")[0].inner_text
            "#{raw.css("#priceblock_ourprice .restOfPrice")[0].inner_text}#{raw.css("#priceblock_ourprice .buyingPrice")[0].inner_text}.#{raw.css("#priceblock_ourprice .restOfPrice")[1].inner_text}"
          elsif raw.css("#priceblock_dealprice") && (dealprice = raw.css("#priceblock_dealprice span")[0])
            dealprice.inner_text
          else
            raw.css("#priceblock_ourprice").inner_text
          end

        summary = raw.at("#productDescription")
        result[:description] = summary.inner_text if summary
        result
      end
    end
  end
end
