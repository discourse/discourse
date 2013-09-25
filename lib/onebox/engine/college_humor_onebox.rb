module Onebox
  module Engine
    class CollegeHumorOnebox
      include Engine
      include OpenGraph

      matches do
        http
        domain("collegehumor")
        has(".com").maybe("/video").maybe("/")
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

