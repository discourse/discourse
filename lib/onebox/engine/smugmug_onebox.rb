module Onebox
  module Engine
    class SmugMugOnebox
      include Engine
      include JSON

      matches do
        http
        words
        domain("smugmug")
        tld("com")
      end

      private

      def data
        binding.pry
        {
          url: @url,
          photographer: raw["author_name"],
          caption: raw["title"],
          image: raw["url"]
        }
      end
    end
  end
end
