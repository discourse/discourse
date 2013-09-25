module Onebox
  module Engine
    class StackExchangeOnebox
      include Engine
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
          url: @url,
          title: raw.css(".question-hyperlink").inner_text,
          question: raw.css(".question .post-text p").first.inner_text
        }
      end
    end
  end
end
