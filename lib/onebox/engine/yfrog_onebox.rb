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
          title: raw.title,
          image: raw.images.first,
          description: raw.description
        }
      end
    end
  end
end

