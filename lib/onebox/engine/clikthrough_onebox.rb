module Onebox
  module Engine
    class ClikThroughOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?:\/\/(?:www.)?clikthrough.com\/theater\/video\/\d+$/
        find "clikthrough.com"
      end

      private

      def record
        {
          url: @url,
          title: @body.title,
          description: @body.description
        }
      end
    end
  end
end
