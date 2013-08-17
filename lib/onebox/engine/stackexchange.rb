module Onebox
  module Engine
    class StackExchange
      include Engine

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
