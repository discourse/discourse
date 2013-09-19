module Onebox
  module Engine
    class GithubGistOnebox
      include Engine
      include JSON

      matches do
        # /^https?:\/\/(?:www\.)?github\.com\/[^\/]+\/[^\/]+\/commit\/.+/
        find "gist.github.com"
      end

      private

      def data
        {
          url: @url
        }
      end
    end
  end
end
