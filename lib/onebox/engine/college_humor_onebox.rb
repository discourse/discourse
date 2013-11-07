module Onebox
  module Engine
    class CollegeHumorOnebox
      include Engine
      include LayoutSupport
      include OpenGraph

      matches do
        http
        domain("collegehumor")
        has(".com").maybe("/video").maybe("/")
      end

      private

      def data
        {
          link: link,
          domain: "http://collegehumor.com",
          badge: "c",
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video].first[:_value]
        }
      end
    end
  end
end

