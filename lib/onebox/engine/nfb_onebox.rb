module Onebox
  module Engine
    class NFBOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?:\/\/(?:www\.)?nfb\.ca\/film\/[-\w]+\/?/
        find "nfb.ca"
      end

      private

      def extracted_data
        {
          url: @url,
          title: @body.title,
          description: @body.description,
          video: @body.metadata[:video].first[:_value]
        }
      end
    end
  end
end

