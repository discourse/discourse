module Onebox
  module Engine
    class HuluOnebox
      include OpenGraph

      private

      def extracted_data
        {
          url: @url,
          title: @body.title,
          # image: @body.images[0],
          # description: @body.description
        }
      end
    end
  end
end

