module Onebox
  module Engine
    class CollegeHumorOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?:\/\/www.collegehumor.com\/video\/.*$/
        find "collegehumor.com"
      end

      private

      def extracted_data
        {
          url: @url,
          title: @body.title,
          image: @body.images[0],
          description: @body.description,
          video: @body.metadata[:video].first[:_value]
        }
      end
    end
  end
end

