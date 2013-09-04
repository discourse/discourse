module Onebox
  module Engine
    class NFBOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?:\/\/(?:www\.)?nfb\.ca\/film\/[-\w]+\/?/
        find "nfb.ca"
      end

      private

      def record
        {
          url: @url,
          title: raw.title,
          description: raw.description,
          video: raw.metadata[:video].first[:_value]
        }
      end
    end
  end
end

