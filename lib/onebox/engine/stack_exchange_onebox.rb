module Onebox
  module Engine
    class StackExchangeOnebox
      include Engine
      include LayoutSupport
      include HTML

      matches do
        http
        domain("stackoverflow")
        tld("com")
        with("/questions/")
      end

      private

      def data
        {
          link: link,
          domain: "http://stackoverflow.com",
          badge: "s",
          title: raw.css(".question-hyperlink").inner_text,
          question: raw.css(".question .post-text p").first.inner_text
        }
      end
    end
  end
end
