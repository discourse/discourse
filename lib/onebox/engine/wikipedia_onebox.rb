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
        {
          link: link,
          domain: "http://wikipedia.com",
          badge: "w",
          title: raw.css("html body h1").inner_text,
          image: raw.css(".infobox .image img").first["src"],
          description: raw.css("html body p").inner_text
        }
      end
    end
  end
end
