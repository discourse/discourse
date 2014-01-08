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
            text << " " unless cnt == 0
            paragraph = paras[cnt].inner_text[0..Onebox::LayoutSupport.max_text]
            paragraph.gsub!(/\[\d+\]/mi, "")
            text << paragraph
            cnt += 1
          end
        end

        text = "#{text[0..Onebox::LayoutSupport.max_text]}..." if text.length > Onebox::LayoutSupport.max_text
        {
          link: link,
          title: raw.css("html body h1").inner_text,
          image: raw.css(".infobox .image img").first["src"],
          description: text
        }
      end
    end
  end
end
