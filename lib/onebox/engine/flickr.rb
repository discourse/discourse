module Onebox
  module Engine
    class FlickrOnebox
      include OpenGraph

      private

      def extracted_data
        {
          url: @url,
          title: @body.title
        }
      end
    end
  end
end

