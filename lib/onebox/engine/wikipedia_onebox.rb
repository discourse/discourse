module Onebox
  module Engine
    class WikipediaOnebox
      include Engine
      include LayoutSupport
      include HTML

      matches do
        http
        anything
        domain("wikipedia")
        either(".com", ".org")
      end

      private

      def data
        # get all the paras
        paras = raw.search("p")
        text = ""

        unless paras.empty?
          cnt = 0
          while text.length < Onebox::LayoutSupport.max_text && cnt <= 3
            break if cnt >= paras.size
            text << " " unless cnt == 0
            paragraph = paras[cnt].inner_text[0..Onebox::LayoutSupport.max_text]
            paragraph.gsub!(/\[\d+\]/mi, "")
            text << paragraph
            cnt += 1
          end
        end

        text = "#{text[0..Onebox::LayoutSupport.max_text]}..." if text.length > Onebox::LayoutSupport.max_text
        result = {
          link: link,
          title: raw.css("html body h1").inner_text,
          description: text
        }
        img = raw.css(".image img")
        if img && img.first
          result[:image] = img.first["src"]
        end

        result
      end
    end
  end
end
