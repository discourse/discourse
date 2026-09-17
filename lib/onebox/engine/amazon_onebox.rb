# frozen_string_literal: true

module Onebox
  module Engine
    class AmazonOnebox
      include Engine
      include LayoutSupport

      always_https
      matches_regexp(
        %r{^https?://(?:www\.)?(?:smile\.)?(amazon|amzn)\.(?<tld>com|ca|de|it|es|fr|co\.jp|co\.uk|cn|in|com\.br|com\.mx|nl|pl|sa|sg|se|com\.tr|ae)/},
      )

      def url
        return @url unless asin

        canonical = @raw&.at('link[rel="canonical"]')&.[]("href").to_s
        return canonical if canonical.match?(%r{/dp/#{asin}\z}i)

        "https://www.amazon.#{@@matcher.match(@url)[:tld]}/dp/#{asin}"
      end

      def to_html
        verified_data
        errors.empty? ? super : ""
      end

      def placeholder_html
        layout.to_html
      end

      def verified_data
        @verified_data ||=
          data.tap do |result|
            %i[title description].each { |tag| errors[tag] = ["is blank"] if result[tag].blank? }
          end
      end

      private

      def asin
        @asin ||= @url[%r{/[dg]p/(?:product/|video/detail/)?([A-Z0-9]+)(?:[/?]|$)}i, 1]
      end

      def raw
        @raw ||=
          Nokogiri.HTML(
            Onebox::Helpers.fetch_response(url, raise_error_when_response_too_large: false),
          )
      rescue StandardError
        @raw = Nokogiri.HTML("")
      end

      def data
        @data ||=
          begin
            og = ::Onebox::OpenGraph.new(raw)
            description =
              og.description || text("#productDescription") ||
                raw.at("meta[name=description]")&.[]("content")

            {
              link: url,
              title: CGI.unescapeHTML(og.title.to_s),
              image: og.image || image,
              description:
                description && CGI.unescapeHTML(Onebox::Helpers.truncate(description, 250)),
              price:,
            }.merge(book_details)
          end
      end

      def book_details
        details =
          if raw.at("#dp.book_mobile")
            row =
              "//div[@id='productDetails_secondary_view_div']//table[@id='productDetails_techSpec_section_1']//tr[%d]//td"
            {
              title: text("h1#title"),
              isbn_asin_text: "ISBN",
              isbn_asin: text(row % 8),
              publisher: text(row % 1),
              published: text(row % 2),
            }
          elsif raw.at("#dp.ebooks_mobile")
            row = "//div[@id='detailBullets_secondary_view_div']//ul//li[%d]/span/span[2]"
            {
              title: text("#ebooksTitle"),
              isbn_asin_text: "ASIN",
              isbn_asin: text(row % 4),
              publisher: text(row % 2),
              published: text(row % 1),
            }
          end

        return {} unless details

        rating =
          text("#averageCustomerReviews_feature_div .a-icon") ||
            text("#acrCustomerReviewLink .a-icon")

        details.merge(
          by_info: text("#byline, #bylineInfo"),
          rating: rating && "#{rating}, ",
          published: details[:published] && "#{details[:published]}#{", " if price}",
        )
      end

      def image
        landing_image = raw.at("#landingImage")

        raw.at("#main-image")&.[]("data-a-hires").presence ||
          landing_image&.[]("data-old-hires").presence || landing_image&.[]("src").presence ||
          raw
            .at("#ebooksImgBlkFront")
            &.[]("data-a-dynamic-image")
            &.then { |json| ::JSON.parse(json).keys.first }
      end

      def price
        amount =
          text("#corePrice_feature_div .a-price .a-offscreen") ||
            text(".mediaMatrixListItem.a-active .a-color-price")

        amount unless amount&.start_with?("$0")
      end

      def text(path)
        raw.at(path)&.inner_text&.strip.presence
      end
    end
  end
end
