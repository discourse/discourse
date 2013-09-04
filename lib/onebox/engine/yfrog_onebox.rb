module Onebox
  module Engine
    class YfrogOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?:\/\/(?:www\.)?yfrog\.(com|ru|com\.tr|it|fr|co\.il|co\.uk|com\.pl|pl|eu|us)\/[a-zA-Z0-9]+/
        find "yfrog.com"
      end

      private

      def record
        {
          url: @url,
          title: @body.title,
          image: @body.images.first,
          description: @body.description
        }
      end
    end
  end
end

