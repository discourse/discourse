module Onebox
  module Engine
    class HuluOnebox
      include Engine
      include OpenGraph

      matches do
        #/^https?\:\/\/www\.hulu\.com\/watch\/.*$/
        find "hulu.com"
      end

      private

      def data
        {
          url: @url,
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video][1][:_value]
        }
      end
    end
  end
end

