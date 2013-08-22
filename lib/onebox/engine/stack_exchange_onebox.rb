module Onebox
  module Engine
    class StackExchangeOnebox
      include Engine

      matches do
        # /^http:\/\/(?:(?:(?<subsubdomain>\w*)\.)?(?<subdomain>\w*)\.)?(?<domain>#{DOMAINS.join('|')})\.com\/(?:questions|q)\/(?<question>\d*)/
        find "stackexchange.com"
      end

      private

      def extracted_data
        {
          url: @url,
          title: @body.css(".question-hyperlink").inner_text,
          question: @body.css(".question .post-text p").first.inner_text
        }
      end
    end
  end
end
