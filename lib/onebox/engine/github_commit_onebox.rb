module Onebox
  module Engine
    class GithubCommitOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?:\/\/(?:www\.)?github\.com\/[^\/]+\/[^\/]+\/commit\/.+/
        find "github.com"
      end

      private

      def data
        {
          url: @url,
          title: raw.title,
          image: raw.images[1],
        }
      end
    end
  end
end
