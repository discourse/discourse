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

      def record
        {
          url: @url,
          title: raw.title,
          image: raw.images[0],
          description: raw.description,
          video: raw.metadata[:video][1][:_value]
        }
      end
    end
  end
end

