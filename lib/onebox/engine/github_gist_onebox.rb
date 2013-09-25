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

      private

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
