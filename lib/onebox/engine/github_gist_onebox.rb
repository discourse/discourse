module Onebox
  module Engine
    class GithubGistOnebox
      include Engine
      include JSON

      matches do
        http
        with("gist.")
        domain("github")
        tld("com")
      end

      def url
        "https://api.github.com/gists/#{match[:number]}"
      end

      private

      def match
        @url.match(/gist\.github\.com\/([^\/]+\/)?(?<number>[0-9a-f]+)/)
      end

      def data
        {
          url: @url,
          content: raw["files"].first[1]["content"],
          author: raw["user"]["login"]
        }
      end
    end
  end
end
