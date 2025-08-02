# frozen_string_literal: true

require "json"
require "onebox/open_graph"

module Onebox
  module Engine
    class AmazonOnebox
      include Engine
      include LayoutSupport
      include HTML

      always_https
      matches_regexp(
        %r{^https?://(?:www\.)?(?:smile\.)?(amazon|amzn)\.(?<tld>com|ca|de|it|es|fr|co\.jp|co\.uk|cn|in|com\.br|com\.mx|nl|pl|sa|sg|se|com\.tr|ae)/},
      )

      def url
        @raw ||= nil

        if @raw
          canonical_link = @raw.at('//link[@rel="canonical"]/@href')
          return canonical_link.to_s if canonical_link
        end

        if match && match[:id]
          id =
            Addressable::URI.encode_component(match[:id], Addressable::URI::CharacterClasses::PATH)
          return "https://www.amazon.#{tld}/dp/#{id}"
        end

        @url
      end

      def tld
        @tld ||= @@matcher.match(@url)["tld"]
      end

      def http_params
        { "User-Agent" => @options[:user_agent] } if @options && @options[:user_agent]
      end

      def to_html(ignore_errors = false)
        unless ignore_errors
          verified_data # forces a check for missing fields
          return "" unless errors.empty?
        end

        super()
      end

      def placeholder_html
        to_html(true)
      end

      def verified_data
        @verified_data ||=
          begin
            result = data

            required_tags = %i[title description]
            required_tags.each do |tag|
              if result[tag].blank?
                errors[tag] ||= []
                errors[tag] << "is blank"
              end
            end

            result
          end

        @verified_data
      end

      private

      def match
        @match ||= @url.match(%r{(?:d|g)p/(?:product/|video/detail/)?(?<id>[A-Z0-9]+)(?:/|\?|$)}mi)
      end

      def image
        if (main_image = raw.css("#main-image")) && main_image.any?
          attributes = main_image.first.attributes

          if attributes["data-a-hires"]
            return attributes["data-a-hires"].to_s
          elsif attributes["data-a-dynamic-image"]
            return ::JSON.parse(attributes["data-a-dynamic-image"].value).keys.first
          end
        end

        if (landing_image = raw.css("#landingImage")) && landing_image.any?
          attributes = landing_image.first.attributes

          if attributes["data-old-hires"]
            return attributes["data-old-hires"].to_s
          else
            return landing_image.first["src"].to_s
          end
        end

        if (ebook_image = raw.css("#ebooksImgBlkFront")) && ebook_image.any?
          ::JSON.parse(ebook_image.first.attributes["data-a-dynamic-image"].value).keys.first
        end
      end

      def price
        # get item price (Amazon markup is inconsistent, deal with it)
        if raw.css("#priceblock_ourprice .restOfPrice")[0] &&
             raw.css("#priceblock_ourprice .restOfPrice")[0].inner_text
          "#{raw.css("#priceblock_ourprice .restOfPrice")[0].inner_text}#{raw.css("#priceblock_ourprice .buyingPrice")[0].inner_text}.#{raw.css("#priceblock_ourprice .restOfPrice")[1].inner_text}"
        elsif raw.css("#priceblock_dealprice") &&
              (dealprice = raw.css("#priceblock_dealprice span")[0])
          dealprice.inner_text
        elsif !raw.css("#priceblock_ourprice").inner_text.empty?
          raw.css("#priceblock_ourprice").inner_text
        else
          result = raw.css("#corePrice_feature_div .a-price .a-offscreen").first&.inner_text
          if result.blank?
            result = raw.css(".mediaMatrixListItem.a-active .a-color-price").inner_text
          end

          result
        end
      end

      def multiple_authors(authors_xpath)
        raw.xpath(authors_xpath).map { |a| a.inner_text.strip }.join(", ")
      end

      def data
        og = ::Onebox::OpenGraph.new(raw)

        if raw.at_css("#dp.book_mobile") # printed books
          title = raw.at("h1#title")&.inner_text
          authors =
            (
              if raw.at_css("#byline_secondary_view_div")
                multiple_authors(
                  "//div[@id='byline_secondary_view_div']//span[@class='a-text-bold']",
                )
              else
                raw.at("#byline")&.inner_text
              end
            )
          rating =
            raw.at("#averageCustomerReviews_feature_div .a-icon")&.inner_text ||
              raw.at("#cmrsArcLink .a-icon")&.inner_text

          table_xpath =
            "//div[@id='productDetails_secondary_view_div']//table[@id='productDetails_techSpec_section_1']"
          isbn = raw.xpath("#{table_xpath}//tr[8]//td").inner_text.strip

          # if ISBN is misplaced or absent it's hard to find out which data is
          # available and where to find it so just set it all to nil
          if /^\d(\-?\d){12}$/.match(isbn)
            publisher = raw.xpath("#{table_xpath}//tr[1]//td").inner_text.strip
            published = raw.xpath("#{table_xpath}//tr[2]//td").inner_text.strip
            book_length = raw.xpath("#{table_xpath}//tr[6]//td").inner_text.strip
          else
            isbn = publisher = published = book_length = nil
          end

          result = {
            link: url,
            title: title,
            by_info: authors,
            image: og.image || image,
            description: raw.at("#productDescription")&.inner_text,
            rating: "#{rating}#{", " if rating && (!isbn&.empty? || !price&.empty?)}",
            price: price,
            isbn_asin_text: "ISBN",
            isbn_asin: isbn,
            publisher: publisher,
            published: "#{published}#{", " if published && !price&.empty?}",
          }
        elsif raw.at_css("#dp.ebooks_mobile") # ebooks
          title = raw.at("#ebooksTitle")&.inner_text
          authors =
            (
              if raw.at_css("#a-popover-mobile-udp-contributor-popover-id")
                multiple_authors(
                  "//div[@id='a-popover-mobile-udp-contributor-popover-id']//span[contains(@class,'a-text-bold')]",
                )
              else
                (raw.at("#byline")&.inner_text&.strip || raw.at("#bylineInfo")&.inner_text&.strip)
              end
            )
          rating =
            raw.at("#averageCustomerReviews_feature_div .a-icon")&.inner_text ||
              raw.at("#cmrsArcLink .a-icon")&.inner_text ||
              raw.at("#acrCustomerReviewLink .a-icon")&.inner_text

          table_xpath = "//div[@id='detailBullets_secondary_view_div']//ul"
          asin = raw.xpath("#{table_xpath}//li[4]/span/span[2]").inner_text

          # if ASIN is misplaced or absent it's hard to find out which data is
          # available and where to find it so just set it all to nil
          if /^[0-9A-Z]{10}$/.match(asin)
            publisher = raw.xpath("#{table_xpath}//li[2]/span/span[2]").inner_text
            published = raw.xpath("#{table_xpath}//li[1]/span/span[2]").inner_text
          else
            asin = publisher = published = nil
          end

          result = {
            link: url,
            title: title,
            by_info: authors,
            image: og.image || image,
            description: raw.at("#productDescription")&.inner_text,
            rating: "#{rating}#{", " if rating && (!asin&.empty? || !price&.empty?)}",
            price: price,
            isbn_asin_text: "ASIN",
            isbn_asin: asin,
            publisher: publisher,
            published: "#{published}#{", " if published && !price&.empty?}",
          }
        else
          title = CGI.unescapeHTML(og.title || raw.css("title").inner_text)
          result = { link: url, title: title, image: og.image || image, price: price }

          result[:by_info] = raw.at("#by-line")
          result[:by_info] = Onebox::Helpers.clean(result[:by_info].inner_html) if result[:by_info]

          summary = raw.at("#productDescription")

          description = og.description || summary&.inner_text&.strip
          description = raw.css("meta[name=description]").first&.[]("content") if description.blank?
          result[:description] = CGI.unescapeHTML(
            Onebox::Helpers.truncate(description, 250),
          ) if description
        end

        result[:price] = nil if result[:price].start_with?("$0") || result[:price] == 0

        result
      end
    end
  end
end
