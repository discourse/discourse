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
          binding.pry
          url: @url,
          title: @body.title,
          image: @body.images.first,
          description: @body.description,
          video: @body.metadata[:video].first[:url].first[:_value]
        }
      end
    end
  end
end
