module Onebox
  module Engine
    class ImgurImageOnebox
      include Engine
      include HTML

      matches do
        # /^https?\:\/\/imgur\.com\/.*$/
        find "imgur.com"
      end

      private

      def data
        {
          url: @url,
          title: raw.css("h2#image-title").inner_text,
          image: raw.css("#image img").first["src"]
        }
      end
    end
  end
end

