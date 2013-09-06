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

      def data
        {
          url: @url,
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video].first[:_value]
        }
      end
    end
  end
end

