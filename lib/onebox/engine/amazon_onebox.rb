# frozen_string_literal: true

require 'json'
require "onebox/open_graph"

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
        {
          'User-Agent' =>
          'Mozilla/5.0 (iPhone; CPU iPhone OS 5_0_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9A405 Safari/7534.48.3'
        }
      end

      private

      def match
        @match ||= @url.match(/(?:d|g)p\/(?:product\/)?(?<id>[^\/]+)(?:\/|$)/mi)
      end

      def image
        if (main_image = raw.css("#main-image")) && main_image.any?
          attributes = main_image.first.attributes

          return attributes["data-a-hires"].to_s if attributes["data-a-hires"]

          if attributes["data-a-dynamic-image"]
            return ::JSON.parse(attributes["data-a-dynamic-image"].value).keys.first
          end
        end

        if (landing_image = raw.css("#landingImage")) && landing_image.any?
          landing_image.first["src"].to_s
        end

        if (ebook_image = raw.css("#ebooksImgBlkFront")) && ebook_image.any?
          ::JSON.parse(ebook_image.first.attributes["data-a-dynamic-image"].value).keys.first
        end
      end

      def price
        # get item price (Amazon markup is inconsistent, deal with it)
        if raw.css("#priceblock_ourprice .restOfPrice")[0] && raw.css("#priceblock_ourprice .restOfPrice")[0].inner_text
          "#{raw.css("#priceblock_ourprice .restOfPrice")[0].inner_text}#{raw.css("#priceblock_ourprice .buyingPrice")[0].inner_text}.#{raw.css("#priceblock_ourprice .restOfPrice")[1].inner_text}"
        elsif raw.css("#priceblock_dealprice") && (dealprice = raw.css("#priceblock_dealprice span")[0])
          dealprice.inner_text
        elsif !raw.css("#priceblock_ourprice").inner_text.empty?
          raw.css("#priceblock_ourprice").inner_text
        else
          raw.css(".mediaMatrixListItem.a-active .a-color-price").inner_text
        end
      end

      def multiple_authors(authors_xpath)
        author_list = raw.xpath(authors_xpath)
        authors = []
        author_list.each { |a| authors << a.inner_text.strip }
        authors.join(", ")
      end

      def data
        og = ::Onebox::OpenGraph.new(raw)

        if raw.at_css('#dp.book_mobile') #printed books
          title = raw.at("h1#title")&.inner_text
          authors = raw.at_css('#byline_secondary_view_div') ? multiple_authors("//div[@id='byline_secondary_view_div']//span[@class='a-text-bold']") : raw.at("#byline")&.inner_text
          rating = raw.at("#averageCustomerReviews_feature_div .a-icon")&.inner_text || raw.at("#cmrsArcLink .a-icon")&.inner_text

          table_xpath = "//div[@id='productDetails_secondary_view_div']//table[@id='productDetails_techSpec_section_1']"
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
            link: link,
            title: title,
            by_info: authors,
            image: og.image || image,
            description: raw.at("#productDescription")&.inner_text,
            rating: "#{rating}#{', ' if rating && (!isbn&.empty? || !price&.empty?)}",
            price: price,
            isbn_asin_text: "ISBN",
            isbn_asin: isbn,
            publisher: publisher,
            published: "#{published}#{', ' if published && !price&.empty?}"
          }

        elsif raw.at_css('#dp.ebooks_mobile') # ebooks
          title = raw.at("#ebooksTitle")&.inner_text
          authors = raw.at_css('#a-popover-mobile-udp-contributor-popover-id') ? multiple_authors("//div[@id='a-popover-mobile-udp-contributor-popover-id']//span[contains(@class,'a-text-bold')]") : (raw.at("#byline")&.inner_text&.strip || raw.at("#bylineInfo")&.inner_text&.strip)
          rating = raw.at("#averageCustomerReviews_feature_div .a-icon")&.inner_text || raw.at("#cmrsArcLink .a-icon")&.inner_text || raw.at("#acrCustomerReviewLink .a-icon")&.inner_text

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
            link: link,
            title: title,
            by_info: authors,
            image: og.image || image,
            description: raw.at("#productDescription")&.inner_text,
            rating: "#{rating}#{', ' if rating && (!asin&.empty? || !price&.empty?)}",
            price: price,
            isbn_asin_text: "ASIN",
            isbn_asin: asin,
            publisher: publisher,
            published: "#{published}#{', ' if published && !price&.empty?}"
          }

        else
          title = og.title || CGI.unescapeHTML(raw.css("title").inner_text)
          result = {
            link: link,
            title: title,
            image: og.image || image,
            price: price
          }

          result[:by_info] = raw.at("#by-line")
          result[:by_info] = Onebox::Helpers.clean(result[:by_info].inner_html) if result[:by_info]

          summary = raw.at("#productDescription")
          result[:description] = og.description || (summary && summary.inner_text)
        end

        result[:price] = nil if result[:price].start_with?("$0") || result[:price] == 0

        result
      end
    end
  end
end
